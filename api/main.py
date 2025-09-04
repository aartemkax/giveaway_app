# api/main.py
import os
import sys
import json
import base64
import logging
import re
import time
import concurrent.futures as futures

from flask import Flask, request, jsonify, session
from flask_cors import CORS
from flask_session import Session
from dotenv import load_dotenv
from redis import Redis
from rq import Queue
from werkzeug.middleware.proxy_fix import ProxyFix

from instagrapi import Client
from instagrapi.exceptions import BadPassword, ChallengeRequired, TwoFactorRequired

from device_emulator import emulate_device
from tasks import fetch_participants_task

# ── Init & logging ─────────────────────────────────────────────────────────────
load_dotenv()
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logger = logging.getLogger("api")

# ── Flask (Session + CORS) ───────────────────────────
app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_host=1)

redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")

app.config.update(
    SECRET_KEY=os.getenv("FLASK_SECRET_KEY", "dev-secret-key"),
    SESSION_TYPE=os.getenv("SESSION_TYPE", "redis"),
    SESSION_COOKIE_SAMESITE=os.getenv("SESSION_COOKIE_SAMESITE", "None"),
    SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "true").lower() == "true",
)
from redis import Redis
# Якщо Railway дасть TLS (`rediss://`), дозволимо під’єднання без сертифіката
_tls = {"ssl_cert_reqs": None} if redis_url.startswith("rediss://") else {}
app.config["SESSION_REDIS"] = Redis.from_url(redis_url, **_tls)

Session(app)

# CORS: дозволяємо будь-який локальний порт (localhost / 127.0.0.1)
# Увага: з credentials не можна '*' — тому використовуємо regex.
allowed = [
    re.compile(r"^http://localhost:\d+$"),
    re.compile(r"^http://127\.0\.0\.1:\d+$"),
]
railway_origin = os.getenv("CORS_ORIGIN", "").strip()
if railway_origin:
    allowed.append(railway_origin)

CORS(
    app,
    supports_credentials=True,
    resources={r"/api/*": {"origins": allowed}},
    allow_headers=["Content-Type"],
    methods=["GET","POST","OPTIONS"],
    expose_headers=["Content-Type"],
)
# ── Redis & RQ ─────────────────────────────────────────────────────────────────
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
redis_conn = Redis.from_url(redis_url)
queue = Queue(connection=redis_conn)

# ── Helpers ────────────────────────────────────────────────────────────────────
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/p/[^/]+/?$")
LOGIN_TIMEOUT_SEC = int(os.getenv("LOGIN_TIMEOUT_SEC", "45"))

@app.before_request
def _log_request():
    logger.info(">> %s %s | headers=%s", request.method, request.path, dict(request.headers))
    try:
        if request.method != "GET":
            logger.info("   body=%s", request.get_data(as_text=True))
    except Exception:
        pass

@app.after_request
def _log_response(resp):
    logger.info("<< %s %s -> %s", request.method, request.path, resp.status)
    return resp

def _do_login(username: str, password: str, settings: dict, ua: str) -> dict:
    cl = Client()
    cl.set_device(settings['device_settings'])
    settings['user_agent'] = ua
    cl.set_settings(settings)
    cl.user_agent = ua
    cl.private.headers.update({"User-Agent": ua})

    logger.info("instagrapi login: start user=%s", username)
    cl.login(username, password)
    logger.info("instagrapi login: success user=%s", username)

    sess = cl.get_settings()
    sess['device_agent'] = ua
    return sess

# ── LOGIN ──────────────────────────────────────────────────────────────────────
# payload: { username, password, deviceInfo }
# return: 200 { settings } + сервер зберігає session["ig_settings"] (cookie)
@app.route('/api/login', methods=['POST', 'OPTIONS'])
def login():
    if request.method == 'OPTIONS':
        return '', 204  # preflight OK

    data = request.get_json(force=True) or {}
    username   = (data.get('username') or '').strip()
    password   = (data.get('password') or '').strip()
    raw_device = data.get('deviceInfo') or {}

    logger.info("LOGIN start for user=%s", username)
    emu      = emulate_device(raw_device, use_phone_code=True)
    settings = emu['settings']
    ua       = emu.get('device_agent')

    start = time.time()
    try:
        with futures.ThreadPoolExecutor(max_workers=1) as ex:
            fut = ex.submit(_do_login, username, password, settings, ua)
            session_settings = fut.result(timeout=LOGIN_TIMEOUT_SEC)
    except futures.TimeoutError:
        logger.error("Login timeout for %s after %ss", username, LOGIN_TIMEOUT_SEC)
        return jsonify({'error': 'gateway_timeout',
                        'detail': f'Login took longer than {LOGIN_TIMEOUT_SEC}s'}), 504
    except BadPassword:
        return jsonify({'error': 'invalid_credentials'}), 401
    except ChallengeRequired:
        return jsonify({'error': 'instagram_challenge'}), 412
    except TwoFactorRequired:
        return jsonify({'error': 'two_factor_required'}), 412
    except Exception as e:
        logger.exception('Login failed')
        return jsonify({'error': 'internal_error', 'detail': str(e)}), 500
    finally:
        logger.info("Login %s finished in %.2fs", username, time.time() - start)

    session["ig_settings"] = session_settings
    return jsonify({'settings': session_settings}), 200

# ── Public utils: geo & device report ──────────────────────────────────────────
@app.route('/api/collect_device_geo', methods=['POST', 'OPTIONS'])
def collect_device_geo():
    if request.method == 'OPTIONS':
        return '', 204  # preflight OK
    ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    try:
        import requests as _rq
        geo = _rq.get(f"https://ipwho.is/{ip}", timeout=2).json()
    except Exception:
        geo = {}
    return jsonify({"geo": geo, "ip": ip})

@app.route('/api/device_report', methods=['POST', 'OPTIONS'])
def device_report():
    if request.method == 'OPTIONS':
        return '', 204  # preflight OK
    info = (request.get_json() or {}).get("deviceInfo", {})
    emu  = emulate_device(info, use_phone_code=True)
    return jsonify(emu)

# --- фрагмент api/main.py (оновлений тільки /api/fetch_participants_async) ---

@app.route('/api/fetch_participants_async', methods=['POST', 'OPTIONS'])
def fetch_async():
    if request.method == 'OPTIONS':
        return '', 204  # preflight OK

    # 🔎 детальний лог того, що реально прийшло
    try:
        raw_body = request.get_data(as_text=True)
    except Exception:
        raw_body = '<cannot read body>'
    logger.info("FETCH_ASYNC: cookies=%s", request.headers.get('Cookie'))
    logger.info("FETCH_ASYNC: body=%s", raw_body)

    # ⛔️ немає інста-сесії в серверній cookie-сесії
    if "ig_settings" not in session:
        logger.warning("FETCH_ASYNC: ig_settings missing in session -> session_expired")
        return jsonify({
            'error': 'login_required',
            'detail': 'session_expired'
        }), 401

    data = request.get_json(force=True) or {}
    post_url = (data.get('post_url') or '').strip()

    # Додамо "/" в кінець для стабільності парсингу
    if post_url and not post_url.endswith('/'):
        post_url += '/'

    logger.info("FETCH_ASYNC: parsed post_url=%s", post_url)

    if not URL_PATTERN.match(post_url):
        logger.warning("FETCH_ASYNC: invalid_post_url")
        return jsonify({'error': 'invalid_post_url'}), 400

    settings_b64 = base64.b64encode(json.dumps(session["ig_settings"]).encode()).decode()
    job = queue.enqueue(
        fetch_participants_task,
        settings_b64,
        post_url,
        False,                 # use_proxy
        data.get('device_info'),
        data.get('region'),
        job_timeout=600,
        result_ttl=3600
    )
    logger.info("FETCH_ASYNC: enqueued job_id=%s for %s", job.id, post_url)
    return jsonify({'job_id': job.id}), 202

# ── Job status & result ────────────────────────────────────────────────────────
@app.route('/api/job_status/<job_id>', methods=['GET', 'OPTIONS'])
def job_status(job_id):
    if request.method == 'OPTIONS':
        return '', 204  # preflight OK
    job = queue.fetch_job(job_id)
    if not job:
        return jsonify({'error': 'not_found'}), 404
    return jsonify({'status': job.get_status()}), 200

@app.route('/api/job_result/<job_id>', methods=['GET', 'OPTIONS'])
def job_result(job_id):
    if request.method == 'OPTIONS':
        return '', 204  # preflight OK
    job = queue.fetch_job(job_id)
    if not job:
        return jsonify({'error': 'not_found'}), 404
    if job.is_finished:
        res = job.result
        if isinstance(res, dict) and 'error' in res:
            return jsonify(res), 400 if res['error'] in ('invalid_post_url', 'login_required') else 500
        return jsonify({'participants': res}), 200
    if job.is_failed:
        return jsonify({'error': 'internal_error', 'detail': str(job.exc_info)}), 500
    return jsonify({'status': job.get_status()}), 202

# ── Debug (для Flutter) ───────────────────────────────────────────────────────
@app.route('/api/debug_session', methods=['GET'])
def debug_session():
    return jsonify({
        "session_keys": list(session.keys()),
        "ig_settings_present": "ig_settings" in session
    }), 200

# ── Health ────────────────────────────────────────────────────────────────────
@app.route('/healthz', methods=['GET'])
def healthz():
    return jsonify({"ok": True}), 200

# ── Root (landing) ─────────────────────────────────────────────────────────────
@app.route('/', methods=['GET'])
def root():
    return jsonify({
        "ok": True,
        "service": "api",
        "routes": [
            "/healthz",
            "/api/login",
            "/api/fetch_participants_async",
            "/api/job_status/<id>",
            "/api/job_result/<id>",
            "/api/debug_session"
        ]
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 8080)), debug=True)
