# api/main.py
import os
import sys
import json
import base64
import logging
import re
import time
import hashlib
import random
import concurrent.futures as futures
import secrets
from datetime import timedelta

from flask import Flask, request, jsonify, session, current_app
from flask_cors import CORS
from flask_session import Session
from dotenv import load_dotenv
from redis import Redis
from rq import Queue, Retry
from werkzeug.middleware.proxy_fix import ProxyFix
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from fb_graph import login_url as fb_login_url, exchange_code_for_token, exchange_long_lived, me, list_pages, ig_media, ig_comments


from instagrapi import Client
from instagrapi.exceptions import (
    BadPassword, ChallengeRequired, TwoFactorRequired,
    UserNotFound, PleaseWaitFewMinutes, LoginRequired, ClientError,
)

from device_emulator import emulate_device
from tasks import fetch_participants_task

# ── Init & logging ─────────────────────────────────────────────────────────────
load_dotenv()

USE_PROXY_ENV = os.getenv("USE_PROXY", "false").lower() == "true"
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# Ліміт постановки задач користувачем у фіксованому вікні
MAX_ACTIVE_JOBS_PER_USER = int(os.getenv("MAX_ACTIVE_JOBS_PER_USER", "3"))
QUEUE_RATE_LIMIT_WINDOW_SEC = int(os.getenv("QUEUE_RATE_LIMIT_WINDOW_SEC", "3600"))  # 1h вікно

LOGIN_TIMEOUT_SEC = int(os.getenv("LOGIN_TIMEOUT_SEC", "45"))

logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logger = logging.getLogger("api")

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Flask (Session + CORS) ───────────────────────────
app = Flask(__name__)
app.permanent_session_lifetime = timedelta(days=int(os.getenv("SESSION_TTL_DAYS", "30")))
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_host=1,
    static_folder=os.path.join(BASE_DIR, "static"), 
    static_url_path="/"
)

app.config.update(
    SECRET_KEY=os.getenv("FLASK_SECRET_KEY", "dev-secret-key"),
    SESSION_TYPE=os.getenv("SESSION_TYPE", "redis"),
    SESSION_COOKIE_SAMESITE=os.getenv("SESSION_COOKIE_SAMESITE", "None"),
    SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "true").lower() == "true",
)
_tls = {"ssl_cert_reqs": None} if redis_url.startswith("rediss://") else {}
app.config["SESSION_REDIS"] = Redis.from_url(redis_url, **_tls)
Session(app)

# CORS
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
    methods=["GET", "POST", "OPTIONS"],
    expose_headers=["Content-Type"],
)

# ── Redis & RQ ─────────────────────────────────────────
redis_conn = Redis.from_url(redis_url, **_tls)
queue = Queue(connection=redis_conn)

# ── Helpers ────────────────────────────────────────────────────────────────────
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/(p|reel|tv)/[^/]+/?$")
MENTION_RE = re.compile(r'@([A-Za-z0-9._]+)')

def _canon_key(p):
    u = str((p.get('username') or '')).lower()
    pid = str(p.get('id') or p.get('pk') or '')
    t = str(p.get('text') or p.get('comment') or '')
    return (u, pid, t)

def _filter_participants(items, *, dedupe_usernames=False,
                         require_mentions=0, require_hashtag=None,
                         blacklist=None):
    out = []
    seen = set()
    tag = (require_hashtag or '').strip()
    tag_lc = tag.lower()
    bl = {x.lower() for x in (blacklist or [])}

    for p in items:
        u = str((p.get('username') or '')).strip()
        if not u or u.lower() in bl:
            continue
        txt = str(p.get('text') or p.get('comment') or '')
        if require_mentions > 0 and len(MENTION_RE.findall(txt)) < require_mentions:
            continue
        if tag_lc and f'#{tag_lc}' not in txt.lower():
            continue
        if dedupe_usernames:
            key = u.lower()
            if key in seen:
                continue
            seen.add(key)
        out.append(p)
    return out

@app.before_request
def _log_request():
    hdrs = dict(request.headers)
    if 'Cookie' in hdrs:
        hdrs['Cookie'] = '<masked>'
    body_preview = ''
    if request.method != "GET":
        try:
            if request.path not in ('/api/login', '/api/login_by_sessionid'):
                body_preview = request.get_data(as_text=True)[:1000]
            else:
                body_preview = '<masked>'
        except Exception:
            body_preview = '<unreadable>'
    logger.info(">> %s %s | headers=%s | body=%s", request.method, request.path, hdrs, body_preview)

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
    proxy_url = os.getenv("PROXY_URL")
    if proxy_url:
        cl.set_proxy(proxy_url)

    cl.delay_range = [2, 5]
    cl.login(username, password)
    logger.info("instagrapi login: success user=%s", username)

    sess = cl.get_settings()
    sess['device_agent'] = ua
    return sess

# ── LOGIN ──────────────────────────────────────────────────────────────────────
@app.route('/api/login', methods=['POST', 'OPTIONS'])
def login():
    if request.method == 'OPTIONS':
        return '', 204

    data = request.get_json(silent=True) or {}
    username   = (data.get('username') or '').strip()
    password   = (data.get('password') or '').strip()
    raw_device = data.get('deviceInfo') or {}

    logger.info("LOGIN start for user=%s", username)

    raw_device.setdefault("userAgent", "Instagram 269.0.0.18.75 Android")
    raw_device.setdefault("platform", "Android")
    raw_device.setdefault("locale", "uk-UA")
    raw_device.setdefault("timezoneOffset", 180)
    raw_device.setdefault("screen", {"width": 1080, "height": 1920, "pixelRatio": 3})

    try:
        emu = session.get('emu_cache')
        if not emu:
            emu = emulate_device(raw_device, use_phone_code=True)
            session['emu_cache'] = emu

        settings = emu['settings']
        ua       = emu.get('device_agent')
    except Exception as e:
        logger.exception("emulate_device failed")
        return jsonify({'error': 'invalid_device_info', 'detail': str(e)}), 400

    try:
        with futures.ThreadPoolExecutor(max_workers=1) as ex:
            fut = ex.submit(_do_login, username, password, settings, ua)
            session_settings = fut.result(timeout=LOGIN_TIMEOUT_SEC)

    except futures.TimeoutError:
        logger.error("Login timeout for %s after %ss", username, LOGIN_TIMEOUT_SEC)
        return jsonify({'error': 'gateway_timeout',
                        'detail': f'Login took longer than {LOGIN_TIMEOUT_SEC}s'}), 504

    except (BadPassword, UserNotFound):
        return jsonify({'error': 'invalid_credentials'}), 401

    except ChallengeRequired:
        return jsonify({'error': 'instagram_challenge'}), 412

    except TwoFactorRequired:
        return jsonify({'error': 'two_factor_required'}), 412

    except PleaseWaitFewMinutes:
        return jsonify({'error': 'rate_limited'}), 429

    except LoginRequired:
        return jsonify({'error': 'login_required'}), 401

    except ClientError as e:
        msg = str(e)
        suspicious_signs = (
            "doesn't belong to an account",
            "Please check your username",
            "Проверьте свое имя пользователя",
            "Не вдалося знайти обліковий запис",
            "не вдалося знайти",
        )
        if any(sign in msg for sign in suspicious_signs):
            return jsonify({'error': 'suspicious_login'}), 403
        logger.exception("ClientError during login")
        return jsonify({'error': 'internal_error', 'detail': msg}), 500

    except Exception as e:
        logger.exception('Login failed (unexpected)')
        return jsonify({'error': 'internal_error', 'detail': str(e)}), 500

    finally:
        logger.info("Login %s finished", username)

    session["ig_settings"] = session_settings
    session['emu_cache'] = {'settings': session_settings, 'device_agent': ua}
    return jsonify({'settings': session_settings}), 200

# ── Public utils: geo & device report ──────────────────────────────────────────
@app.route('/api/collect_device_geo', methods=['POST', 'OPTIONS'])
def collect_device_geo():
    if request.method == 'OPTIONS':
        return '', 204
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
        return '', 204

    data = request.get_json(silent=True) or {}
    info = data.get('deviceInfo') or data or {}

    info.setdefault("userAgent", "Instagram 269.0.0.18.75 Android")
    info.setdefault("platform", "Android")
    info.setdefault("locale", "uk-UA")
    info.setdefault("timezoneOffset", 180)
    info.setdefault("screen", {"width": 1080, "height": 1920, "pixelRatio": 3})

    try:
        emu = emulate_device(info, use_phone_code=True)
        session['emu_cache'] = emu
        return jsonify(emu), 200
    except Exception as e:
        msg = str(e)
    if "CSRF token missing" in msg:
        return jsonify({"error":"proxy_blocked","detail":"csrf_missing"}), 502
    return jsonify({"error":"invalid_device_info","detail":msg}), 400

# ── Async fetch with queue-limit 429 (distinct from IG 429) ────────────────────
@app.route('/api/fetch_participants_async', methods=['POST', 'OPTIONS'])
def fetch_async():
    if request.method == 'OPTIONS':
        return '', 204

    try:
        raw_body = request.get_data(as_text=True)
    except Exception:
        raw_body = '<cannot read body>'
    logger.info("FETCH_ASYNC: cookies=<present:%s>", 'Cookie' in request.headers)
    logger.info("FETCH_ASYNC: body=%s", raw_body)

    if "ig_settings" not in session:
        logger.warning("FETCH_ASYNC: ig_settings missing in session -> session_expired")
        return jsonify({'error': 'login_required', 'detail': 'session_expired'}), 401

    # ⬇️ ОТРИМАТИ ТІЛО + НОРМАЛІЗАЦІЯ URL
    data = request.get_json(force=True) or {}
    raw = (data.get('post_url') or '').strip()
    post_url = raw.split('?', 1)[0].split('#', 1)[0]
    if post_url and not post_url.endswith('/'):
        post_url += '/'

    logger.info("FETCH_ASYNC: normalized post_url=%s", post_url)

    if not URL_PATTERN.match(post_url):
        logger.warning("FETCH_ASYNC: invalid_post_url")
        return jsonify({'error': 'invalid_post_url'}), 400

    # пер-користувацький ліміт у фіксованому вікні (залишаєш як було)
    session_cookie_name = app.config.get("SESSION_COOKIE_NAME", "session")
    sid = request.cookies.get(session_cookie_name)
    client_id = sid or request.remote_addr or "anon"

    rl_key = f"rq:rate:{client_id}"
    n = redis_conn.incr(rl_key)
    if n == 1:
        redis_conn.expire(rl_key, QUEUE_RATE_LIMIT_WINDOW_SEC)

    if n > MAX_ACTIVE_JOBS_PER_USER:
        ttl = redis_conn.ttl(rl_key)
        retry_after = ttl if isinstance(ttl, int) and ttl > 0 else QUEUE_RATE_LIMIT_WINDOW_SEC
        payload = {
            'error': 'too_many_jobs',
            'limit': MAX_ACTIVE_JOBS_PER_USER,
            'active': min(n - 1, MAX_ACTIVE_JOBS_PER_USER),
            'retryAfter': retry_after,
            'detail': 'active jobs limit hit in fixed window'
        }
        resp = jsonify(payload)
        resp.status_code = 429
        resp.headers['Retry-After'] = str(retry_after)
        resp.headers['X-RateLimit-Limit'] = str(MAX_ACTIVE_JOBS_PER_USER)
        resp.headers['X-RateLimit-Remaining'] = str(max(0, MAX_ACTIVE_JOBS_PER_USER - (n - 1)))
        resp.headers['X-RateLimit-Reset'] = str(retry_after)
        return resp

    try:
        settings_b64 = base64.b64encode(json.dumps(session["ig_settings"]).encode()).decode()
        job = queue.enqueue(
            fetch_participants_task,
            settings_b64,
            post_url,
            USE_PROXY_ENV,
            data.get('device_info'),
            data.get('region'),
            job_timeout=600,
            result_ttl=3600,
            retry=Retry(max=3, interval=[30, 120, 300]),
            meta={'client_id': client_id}
        )
        logger.info("FETCH_ASYNC: enqueued job_id=%s for %s", job.id, post_url)
        return jsonify({'job_id': job.id}), 202

    except Exception as e:
        logger.exception("FETCH_ASYNC: enqueue failed")
        return jsonify({'error': 'internal_error', 'detail': str(e)}), 500

# ── Deterministic draw ─────────────────────────────────────────────────────────
@app.route('/api/draw', methods=['POST', 'OPTIONS'])
def draw():
    if request.method == 'OPTIONS':
        return '', 204

    data = request.get_json(silent=True) or {}
    participants = data.get('participants') or []
    if not isinstance(participants, list) or not participants:
        return jsonify({'error':'validation_error','detail':'participants required'}), 400

    try:
        n = max(1, int(data.get('n') or 1))
    except Exception:
        return jsonify({'error':'validation_error','detail':'invalid n'}), 400

    rules = data.get('rules') or {}
    dedupe = bool(rules.get('dedupe_usernames', False))
    req_mentions = int(rules.get('require_mentions') or 0)
    req_hashtag = (rules.get('require_hashtag') or '').strip()
    blacklist = rules.get('blacklist') or []

    filt = _filter_participants(
        participants,
        dedupe_usernames=dedupe,
        require_mentions=req_mentions,
        require_hashtag=req_hashtag,
        blacklist=blacklist
    )
    if not filt:
        return jsonify({'error':'validation_error','detail':'no eligible participants'}), 400

    canon = sorted(filt, key=_canon_key)

    seed = str(data.get('seed') or f"{int(time.time())}:{request.remote_addr or ''}")
    basis = json.dumps(canon, ensure_ascii=False, sort_keys=True, separators=(',',':')) + '|' + seed
    h = hashlib.sha256(basis.encode('utf-8')).hexdigest()
    rnd = random.Random(int(h[:16], 16))

    pool = canon[:]
    rnd.shuffle(pool)

    k = min(n, len(pool))
    winners = pool[:k]

    return jsonify({
        'winners': winners,
        'count': k,
        'eligible': len(canon),
        'proof': h,
        'seed': seed,
        'rules': {
            'dedupe_usernames': dedupe,
            'require_mentions': req_mentions,
            'require_hashtag': req_hashtag,
            'blacklist': blacklist,
        }
    }), 200

# ── Job status & result ────────────────────────────────────────────────────────
@app.route('/api/job_status/<job_id>', methods=['GET', 'OPTIONS'])
def job_status(job_id):
    if request.method == 'OPTIONS':
        return '', 204
    job = queue.fetch_job(job_id)
    if not job:
        return jsonify({'error': 'not_found'}), 404
    return jsonify({'status': job.get_status()}), 200

@app.route('/api/job_result/<job_id>', methods=['GET', 'OPTIONS'])
def job_result(job_id):
    if request.method == 'OPTIONS':
        return '', 204
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

# ── Debug ──────────────────────────────────────────────────────────────────────
@app.route('/api/debug_session', methods=['GET'])
def debug_session():
    return jsonify({
        "session_keys": list(session.keys()),
        "ig_settings_present": "ig_settings" in session
    }), 200

# ── Health & Metrics ───────────────────────────────────────────────────────────
@app.route('/healthz', methods=['GET'])
def healthz():
    return jsonify({"ok": True}), 200

@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

# ── Root (landing) ─────────────────────────────────────────────────────────────
@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "service": "giveaway_api",
        "endpoints": [
            "/healthz",
            "/api/login",
            "/api/collect_device_geo",
            "/api/device_report",
            "/api/fetch_participants_async",
            "/api/job_status/<job_id>",
            "/api/job_result/<job_id>",
            "/api/draw",
            "/api/debug_session",
        ]
    }), 200

# ── Session auth utils ─────────────────────────────────────────────────────────
@app.route('/api/login_by_sessionid', methods=['POST', 'OPTIONS'])
def login_by_sessionid():
    if request.method == 'OPTIONS':
        return '', 204
    data = request.get_json(silent=True) or {}
    sid = (data.get('sessionid') or '').strip()
    if not sid:
        return jsonify({'error': 'validation_error', 'detail': 'sessionid required'}), 400

    emu = session.get('emu_cache') or emulate_device({}, use_phone_code=True)
    cl = Client()
    cl.set_settings(emu['settings'])

    proxy_url = os.getenv("PROXY_URL")
    if proxy_url:
        cl.set_proxy(proxy_url)
    cl.delay_range = [2, 5]

    try:
        ok = cl.login_by_sessionid(sid)
        if not ok:
            return jsonify({'error': 'invalid_sessionid'}), 401
    except Exception as e:
        logger.exception("login_by_sessionid failed")
        return jsonify({'error': 'internal_error', 'detail': str(e)}), 500

    session['ig_settings'] = cl.get_settings()
    session['emu_cache'] = {'settings': session['ig_settings'], 'device_agent': cl.user_agent}
    return jsonify({'ok': True}), 200

def _save_fb_tokens(user_token: str, expires_in: int):
    session["fb_user_token"] = user_token
    session["fb_token_expires_at"] = int(time.time()) + int(expires_in)

def _require_fb():
    tok = session.get("fb_user_token")
    if not tok:
        return None
    # можна перевіряти просту просрочку:
    if int(session.get("fb_token_expires_at", 0)) <= int(time.time()) + 60:
        # TODO: оновлення через long-lived повторно або просити перелогін
        pass
    return tok

@app.get("/api/fb/login_url")
def fb_login_url_endpoint():
    state = secrets.token_urlsafe(16)
    session["fb_oauth_state"] = state
    scopes = [
        "public_profile","email",
        "pages_show_list","pages_read_engagement",
        "instagram_basic","instagram_manage_comments",
    ]
    return jsonify({"url": fb_login_url(state, scopes)})

@app.get("/api/fb/callback")
def fb_callback():
    code  = request.args.get("code")
    state = request.args.get("state")
    if not code or state != session.get("fb_oauth_state"):
        return jsonify({"error":"oauth_failed","detail":"state mismatch or no code"}), 400
    try:
        short = exchange_code_for_token(code)           # ~1h
        longl = exchange_long_lived(short["access_token"])  # ~60 days
        _save_fb_tokens(longl["access_token"], longl.get("expires_in", 60*24*3600))
        who = me(longl["access_token"])
        return jsonify({"ok": True, "me": who}), 200
    except Exception as e:
        logger.exception("fb callback failed")
        return jsonify({"error":"oauth_failed","detail":str(e)}), 400
    
@app.get("/api/ig/accounts")
def ig_accounts():
    tok = _require_fb()
    if not tok:
        return jsonify({"error":"login_required","detail":"fb"}), 401
    try:
        pages = list_pages(tok)
        # Витягнемо IG business акаунти (тільки де є instagram_business_account)
        rows = []
        for p in (pages.get("data") or []):
            ig = (p.get("instagram_business_account") or {})
            if ig.get("id"):
                rows.append({
                    "page_id": p.get("id"),
                    "page_name": p.get("name"),
                    "ig_user_id": ig.get("id"),
                    "ig_username": ig.get("username"),
                })
        return jsonify({"accounts": rows}), 200
    except Exception as e:
        logger.exception("ig_accounts failed")
        return jsonify({"error":"internal_error","detail":str(e)}), 500

@app.get("/api/ig/media")
def ig_media_list():
    tok = _require_fb()
    if not tok:
        return jsonify({"error":"login_required","detail":"fb"}), 401
    ig_user_id = request.args.get("ig_user_id","").strip()
    after = request.args.get("after")
    if not ig_user_id:
        return jsonify({"error":"validation_error","detail":"ig_user_id required"}), 400
    try:
        m = ig_media(ig_user_id, tok, limit=50, after=after)
        return jsonify(m), 200
    except Exception as e:
        logger.exception("ig_media_list failed")
        return jsonify({"error":"internal_error","detail":str(e)}), 500

@app.get("/api/ig/comments")
def ig_comments_list():
    tok = _require_fb()
    if not tok:
        return jsonify({"error":"login_required","detail":"fb"}), 401
    media_id = request.args.get("media_id","").strip()
    after = request.args.get("after")
    if not media_id:
        return jsonify({"error":"validation_error","detail":"media_id required"}), 400
    try:
        c = ig_comments(media_id, tok, limit=100, after=after)
        # нормалізуємо до твоєї моделі participants
        items = []
        for row in (c.get("data") or []):
            items.append({
                "id": row.get("id"),
                "username": row.get("username") or "",
                "text": row.get("text") or "",
                "timestamp": row.get("timestamp"),
            })
        res = {"participants": items, "paging": c.get("paging")}
        return jsonify(res), 200
    except Exception as e:
        logger.exception("ig_comments failed")
        return jsonify({"error":"internal_error","detail":str(e)}), 500

@app.route('/api/logout', methods=['POST', 'OPTIONS'])
def logout():
    if request.method == 'OPTIONS':
        return '', 204
    session.clear()
    return jsonify({'ok': True}), 200

@app.get("/privacy")
def privacy_page():
    # віддасть api/static/privacy.html з кодом 200
    return current_app.send_static_file("privacy.html")


@app.get("/data-deletion")
def data_deletion_page():
    # віддасть api/static/data-deletion.html з кодом 200
    return current_app.send_static_file("data-deletion.html")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 8080)), debug=True)
