# api/main.py
from datetime import timedelta
import os
import sys
import json
import base64
import logging
import re
import time
import secrets
import concurrent.futures as futures
import random, hashlib
import csv, io
import requests as rq
GRAPH = "https://graph.facebook.com/v21.0"

from flask import Flask, request, jsonify, session, Response
from flask_cors import CORS
from flask_session import Session
from dotenv import load_dotenv
from redis import Redis
from rq import Queue
from werkzeug.middleware.proxy_fix import ProxyFix

from instagrapi import Client
from instagrapi.exceptions import (
    BadPassword, ChallengeRequired, TwoFactorRequired,
    UserNotFound, PleaseWaitFewMinutes, LoginRequired, ClientError,
)

from device_emulator import emulate_device
from tasks import fetch_participants_task

# ── Init & logging ─────────────────────────────────────────────────────────────
load_dotenv()  # ВАЖЛИВО: до імпорту fb_graph
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logger = logging.getLogger("api")

# ── FB Graph (імпорт після dotenv) ────────────────────────────────────────────
fb_import_error = None
try:
    from fb_graph import (
    login_url as fb_login_url,
    exchange_code_for_token as fb_exchange_code_for_token,
    exchange_long_lived as fb_exchange_long_lived,
    me, list_pages, ig_media, ig_comments,
)
except Exception as e:
    fb_import_error = e
    fb_login_url = fb_exchange_code_for_token = fb_exchange_long_lived = None
    me = list_pages = ig_media = ig_comments = None

# ── Flask (Session + CORS) ────────────────────────────────────────────────────
app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_host=1)

redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
_tls = {"ssl_cert_reqs": None} if redis_url.startswith("rediss://") else {}

app.config.update(
    SECRET_KEY=os.getenv("FLASK_SECRET_KEY", "dev-secret-key"),
    SESSION_TYPE=os.getenv("SESSION_TYPE", "redis"),
    SESSION_COOKIE_SAMESITE=os.getenv("SESSION_COOKIE_SAMESITE", "None"),
    SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "true").lower() == "true",
    SESSION_REDIS=Redis.from_url(redis_url, **_tls),
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_PERMANENT=False,  # уникаємо довгоживучих сесій
    PERMANENT_SESSION_LIFETIME=timedelta(hours=12),
)
Session(app)

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

# ── Redis & RQ ────────────────────────────────────────────────────────────────
redis_conn = Redis.from_url(redis_url, **_tls)
queue = Queue(connection=redis_conn)

# ── Helpers ────────────────────────────────────────────────────────────────────
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/(p|reel|tv)/[^/]+/?$")
LOGIN_TIMEOUT_SEC = int(os.getenv("LOGIN_TIMEOUT_SEC", "45"))

@app.before_request
def _log_request():
    hdrs = dict(request.headers)
    if 'Cookie' in hdrs:
        hdrs['Cookie'] = '<masked>'
    body_preview = ''
    if request.method != "GET":
        try:
            body_preview = request.get_data(as_text=True)[:1000]
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

# ── LOGIN (instagrapi) ────────────────────────────────────────────────────────
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
        suspicious = (
            "doesn't belong to an account",
            "Please check your username",
            "Проверьте свое имя пользователя",
            "Не вдалося знайти обліковий запис",
            "не вдалося знайти",
        )
        if any(s in msg for s in suspicious):
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

# ── Public utils ───────────────────────────────────────────────────────────────
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
        return jsonify(emu), 200
    except Exception as e:
        msg = str(e)
    if "CSRF token missing" in msg:
        return jsonify({"error": "proxy_blocked", "detail": "csrf_missing"}), 502
    return jsonify({"error": "invalid_device_info", "detail": msg}), 400

# ── Async fetch ────────────────────────────────────────────────────────────────
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
        logger.warning("FETCH_ASYNC: ig_settings missing -> session_expired")
        return jsonify({'error': 'login_required', 'detail': 'session_expired'}), 401

    data = request.get_json(force=True) or {}
    post_url = (data.get('post_url') or '').strip()
    if post_url and not post_url.endswith('/'):
        post_url += '/'

    logger.info("FETCH_ASYNC: normalized post_url=%s", post_url)

    if not URL_PATTERN.match(post_url):
        logger.warning("FETCH_ASYNC: invalid_post_url")
        return jsonify({'error': 'invalid_post_url'}), 400

    settings_b64 = base64.b64encode(json.dumps(session["ig_settings"]).encode()).decode()
    job = queue.enqueue(
        fetch_participants_task,
        settings_b64,
        post_url,
        False,
        data.get('device_info'),
        data.get('region'),
        job_timeout=600,
        result_ttl=3600
    )
    logger.info("FETCH_ASYNC: enqueued job_id=%s for %s", job.id, post_url)
    return jsonify({'job_id': job.id}), 202

# ── Job status & result ────────────────────────────────────────────────────────
@app.route('/api/job/<job_id>', methods=['GET', 'OPTIONS'])
def job_view(job_id):
    if request.method == 'OPTIONS':
        return '', 204
    job, err = _get_job_or_404(job_id)
    if err: return err
    return _job_http_response(job)

# ── Debug ──────────────────────────────────────────────────────────────────────
@app.route('/api/debug_session', methods=['GET'])
def debug_session():
    return jsonify({
        "session_keys": list(session.keys()),
        "ig_settings_present": "ig_settings" in session,
        "fb_user_token_present": "fb_user_token" in session,
    }), 200

@app.get("/__routes_dbg", endpoint="__routes_dbg")
def __routes_dbg():
    rules = sorted(str(r) for r in app.url_map.iter_rules())
    return jsonify({"rules": rules, "dbg": True}), 200

@app.get("/api/ig/comments_debug")
def ig_comments_debug():
    user_tok = _require_fb()
    if not user_tok:
        return jsonify({"error":"login_required"}), 401
    media_id = (request.args.get("media_id") or "").strip()
    page_id  = (request.args.get("page_id") or "").strip()
    if not media_id:
        return jsonify({"error":"validation_error","detail":"media_id required"}), 400

    access_token = user_tok
    if page_id:
        acc = rq.get(f"{GRAPH}/{page_id}",
                     params={"fields":"access_token","access_token":user_tok}, timeout=20).json()
        access_token = acc.get("access_token") or access_token

    # 1) лічильники по медіа
    meta = rq.get(f"{GRAPH}/{media_id}",
                  params={"fields":"id,comments_count,like_count","access_token":access_token},
                  timeout=20).json()
    # 2) перші 5 коментів
    comm = rq.get(f"{GRAPH}/{media_id}/comments",
                  params={"fields":"id,username,text,timestamp", "limit":5, "access_token":access_token},
                  timeout=20).json()
    return jsonify({"meta": meta, "sample": comm}), 200

@app.get("/api/fb/env_debug")
def fb_env_debug():
    return jsonify({
        "FB_APP_ID_set": bool(os.getenv("FB_APP_ID")),
        "FB_APP_SECRET_set": bool(os.getenv("FB_APP_SECRET")),
        "FB_REDIRECT_URI": os.getenv("FB_REDIRECT_URI"),
        "fb_import_error": str(fb_import_error) if fb_import_error else None,
    }), 200

@app.get("/api/fb/debug_pages")
def fb_debug_pages():
    tok = _require_fb()
    if not tok:
        return jsonify({"error": "login_required"}), 401
    try:
        raw = list_pages(tok)
        return jsonify(raw), 200
    except Exception as e:
        logger.exception("fb_debug_pages failed")
        return jsonify({"error": "graph_error", "detail": str(e)}), 500
    
@app.get("/api/fb/page_debug")
def fb_page_debug():
    pid = (request.args.get("page_id") or "").strip()
    if not pid:
        return jsonify({"error": "validation_error", "detail": "page_id required"}), 400

    tok = _require_fb()
    if not tok:
        return jsonify({"error": "login_required"}), 401

    # 1) Отримаємо базові поля Page + IG-зв’язок (без 'perms'!)
    page_fields = (
        "id,name,"
        "instagram_business_account{id,username,name},"
        "connected_instagram_account{id,username},"
        "picture{url}"
    )
    page = rq.get(
        f"{GRAPH}/{pid}",
        params={"fields": page_fields, "access_token": tok},
        timeout=20
    ).json()

    # 2) Спробуємо витягнути page access token (потрібні права на сторінку)
    page_token = None
    try:
        acc = rq.get(
            f"{GRAPH}/{pid}",
            params={"fields": "access_token", "access_token": tok},
            timeout=20
        ).json()
        page_token = acc.get("access_token")
    except Exception:
        pass

    # 3) Якщо маємо IG user id — збагачуємо мінімальною інфою
    ig_block = page.get("instagram_business_account") or page.get("connected_instagram_account") or {}
    ig_user_id = ig_block.get("id")

    ig_profile = None
    if ig_user_id and page_token:
        try:
            ig_profile = rq.get(
                f"{GRAPH}/{ig_user_id}",
                params={"fields": "id,username,followers_count,media_count", "access_token": page_token},
                timeout=20
            ).json()
        except Exception as e:
            ig_profile = {"error": str(e)}

    return jsonify({
        "page_id": pid,
        "page": page,
        "page_access_token_present": bool(page_token),
        "ig_user_id": ig_user_id,
        "ig_profile": ig_profile,
    }), 200

@app.get("/api/fb/import_debug")
def fb_import_dbg():
    info = {
        "fb_import_error": str(fb_import_error) if fb_import_error else None,
    }
    try:
        import api.fb_graph as m
        info["module"] = str(m)
        info["module_file"] = getattr(m, "__file__", None)
    except Exception as e:
        info["module_exc"] = str(e)
    return jsonify(info), 200

@app.get("/api/fb/_whoami")
def fb_whoami():
    tok = session.get("fb_user_token")
    if not tok:
        return jsonify({"error": "login_required"}), 401

    import requests as rq
    GRAPH = "https://graph.facebook.com/v21.0"

    def q(path: str, **params):
        r = rq.get(f"{GRAPH}/{path}", params={**params, "access_token": tok}, timeout=15)
        return r.json()

    app_token = f"{os.getenv('FB_APP_ID')}|{os.getenv('FB_APP_SECRET')}"
    debug = rq.get(f"{GRAPH}/debug_token",
                   params={"input_token": tok, "access_token": app_token},
                   timeout=15).json()

    return jsonify({
        "me": q("me", fields="id,name"),
        "scopes": q("me/permissions"),
        "accounts": q("me/accounts", fields="id,name,tasks"),
        "debug": debug
    }), 200

# ── FB Diag ───────────────────────────────────────────────────────────────────
@app.get("/api/fb/diag")
def fb_diag():
    err = _ensure_fb_ready()
    if err:
        return jsonify(err[0]), err[1]
    tok = _require_fb()
    if not tok:
        return jsonify({"error":"login_required"}), 401

    import requests as rq
    GRAPH = "https://graph.facebook.com/v21.0"

    def q(path, **params):
        r = rq.get(f"{GRAPH}/{path}", params={**params, "access_token": tok}, timeout=20)
        try:
            return r.json()
        except Exception:
            return {"error":"bad_json","text":r.text}

    me = q("me", fields="id,name")
    perms = q("me/permissions")
    pages = q("me/accounts",
              fields="id,name,perms,instagram_business_account,connected_instagram_account")

    # Для кожної Page ще раз явно тягнемо IG-поля
    pages_details = []
    for p in (pages.get("data") or []):
        pid = p.get("id")
        if not pid: 
            continue
        details = q(pid, fields="id,name,instagram_business_account,connected_instagram_account")
        pages_details.append(details)

    return jsonify({
        "me": me,
        "permissions": perms,          # перевір статуси granted/declined
        "pages": pages,                # чи є взагалі сторінки
        "pages_details": pages_details # чи підв’язаний IG до кожної
    }), 200

# ── Health ────────────────────────────────────────────────────────────────────
@app.route('/healthz', methods=['GET'])
def healthz():
    return jsonify({"ok": True}), 200

# ── Privacy & Data Deletion ────────────────────────────────────────────────────
@app.get("/privacy")
def privacy_page():
    html = """
    <!doctype html><meta charset="utf-8">
    <title>Privacy Policy</title>
    <h1>Privacy Policy</h1>
    <p>We only process data necessary to run the giveaway tool. 
    We do not sell or share personal data with third parties.</p>
    <h2>Contact</h2>
    <p>Email: support@example.com</p>
    """
    return html, 200, {"Content-Type": "text/html; charset=utf-8"}

@app.get("/data-deletion")
def data_deletion_page():
    html = """
    <!doctype html><meta charset="utf-8">
    <title>Data Deletion</title>
    <h1>Data Deletion Instructions</h1>
    <p>If you want your data deleted, email support@example.com with your IG/FB ID. 
    We will delete server-side session data and job artifacts within 24–72 hours.</p>
    """
    return html, 200, {"Content-Type": "text/html; charset=utf-8"}

# ── Facebook OAuth & Graph ─────────────────────────────────────────────────────
def _save_fb_tokens(user_token: str, expires_in: int):
    session["fb_user_token"] = user_token
    session["fb_token_expires_at"] = int(time.time()) + int(expires_in)

def _require_fb():
    tok = session.get("fb_user_token")
    if not tok:
        return None
    if int(session.get("fb_token_expires_at", 0)) <= int(time.time()) + 60:
        # місце для авто-оновлення long-lived у майбутньому
        pass
    return tok

def _ensure_fb_ready():
    if fb_import_error:
        return {"error": "fb_module_error", "detail": str(fb_import_error)}, 503
    missing = [k for k in ("FB_APP_ID", "FB_APP_SECRET", "FB_REDIRECT_URI") if not os.getenv(k)]
    if missing:
        return {"error": "fb_env_missing", "detail": f"Missing env: {', '.join(missing)}"}, 503
    return None

@app.get("/api/fb/login_url")
def fb_login_url_endpoint():
    sp = (request.headers.get("Sec-Purpose") or "").lower()
    p  = (request.headers.get("Purpose") or "").lower()
    if "prefetch" in sp or "prefetch" in p:
        return "", 204

    err = _ensure_fb_ready()
    if err:
        return jsonify(err[0]), err[1]

    state = secrets.token_urlsafe(16)
    states = session.get("fb_oauth_states", [])
    now = time.time()
    states = [(s, t) for (s, t) in states if now - t < 300]
    states.append((state, now))
    session["fb_oauth_states"] = states

    scopes = [
        "public_profile", "email",
        "pages_show_list", "pages_read_engagement",
        "instagram_basic", "instagram_manage_comments",
    ]
    try:
        url = fb_login_url(state, scopes)
        resp = jsonify({"url": url})
        resp.headers["Cache-Control"] = "no-store"
        return resp
    except Exception as e:
        logger.exception("fb_login_url failed")
        return jsonify({"error": "config_error", "detail": str(e)}), 503
    
@app.get("/api/fb/callback")
def fb_callback():
    return "<html><body>OK. You can close this page.</body></html>", 200


# @app.get("/api/fb/callback")
# def fb_callback():
#     code  = request.args.get("code")
#     state = request.args.get("state")

#     allowed = {s for s, _ in (session.get("fb_oauth_states") or [])}
#     if not code or state not in allowed:
#         return jsonify({"error": "oauth_failed", "detail": "state mismatch or no code"}), 400

    session["fb_oauth_states"] = [(s, t) for (s, t) in (session.get("fb_oauth_states") or []) if s != state]

    try:
        short = fb_exchange_code_for_token(code)
        try:
            longl = fb_exchange_long_lived(short["access_token"])
            token = longl["access_token"]
            expires_in = int(longl.get("expires_in", 60*24*3600))
        except Exception:
            token = short["access_token"]
            expires_in = int(short.get("expires_in", 3600))

        _save_fb_tokens(token, expires_in)
        who = me(token)
        return jsonify({"ok": True, "me": who}), 200

    except Exception as e:
        logger.exception("fb callback failed")
        return jsonify({"error": "oauth_failed", "detail": str(e)}), 400
    
# ── Utilities ─────────────────────────────────────────────
def _filter_participants(
    rows,
    required_hashtags=None,
    min_mentions=0,
    started_at=None,
    ended_at=None,
    denylist=None,
    unique_by="user",   # "user" | "comment" | "both" Якщо хочеш розігрувати за КОМЕНТАРЯМИ (кожен коментар — окремий квиток), викликай "unique_by": "comment"
):
    """
    unique_by:
      - "user"    : один запис на одного користувача (де-дубль за username)
      - "comment" : один запис на один коментар (де-дубль за id)
      - "both"    : і за username, і за id
    """
    required_hashtags = [str(h or "").lower().strip() for h in (required_hashtags or []) if h]
    # denylist робимо case-insensitive + trim
    denylist = {str(u or "").lower().strip() for u in (denylist or []) if u}

    seen_users = set()
    seen_comments = set()
    out = []

    for r in rows or []:
        # нормалізація полів
        raw_username = r.get("username") or ""
        norm_username = raw_username.strip().lower()
        comment_id = (r.get("id") or "").strip()

        # фільтр denylist
        if norm_username in denylist:
            continue

        # унікальність
        if unique_by in ("user", "both"):
            if norm_username in seen_users:
                continue
        if unique_by in ("comment", "both"):
            if comment_id and comment_id in seen_comments:
                continue

        # умови за текстом та @mentions
        txt = r.get("text") or ""
        if required_hashtags and not any(h in txt.lower() for h in required_hashtags):
            continue

        mentions = len(re.findall(r'@[A-Za-z0-9_.]+', txt))
        if mentions < int(min_mentions or 0):
            continue

        # фільтр за часом (ISO8601 рядки порівнюються лексикографічно коректно)
        ts = r.get("timestamp")
        if started_at and ts and ts < started_at:
            continue
        if ended_at and ts and ts > ended_at:
            continue

        # пройшло — додаємо у результат, але повертаємо оригінальний username
        out.append({
            "id": comment_id,
            "username": raw_username,  # не псуємо регістр/пробіли у відповіді
            "text": txt,
            "timestamp": ts,
        })

        # відмічаємо побачені
        if norm_username:
            seen_users.add(norm_username)
        if comment_id:
            seen_comments.add(comment_id)

    return out

def _normalize_participants(payload):
    """
    Приймає різні варіанти структури з коментарями та повертає
    плоский list[dict] коментарів.
    Підтримує:
    - { "participants": [...] }
    - [ { "count": N, "participants": [...] } ]
    - [ { "participants": [...] }, { "participants": [...] }, ... ]
    - вже плоский список: [ {id, username, text, timestamp}, ... ]
    - об’єкт з ключем "count" і "participants" на верхньому рівні
    """
    rows = payload if payload is not None else []

    # Якщо це dict із "participants" на верхньому рівні
    if isinstance(rows, dict):
        if "participants" in rows and isinstance(rows["participants"], list):
            rows = rows["participants"]
        # інколи приходить {"count": N, "participants": [...]}
        elif "count" in rows and "participants" in rows and isinstance(rows["participants"], list):
            rows = rows["participants"]

    # Якщо це одноелементний список із {"participants":[...]}
    if (isinstance(rows, list) and len(rows) == 1 and isinstance(rows[0], dict)
            and "participants" in rows[0] and isinstance(rows[0]["participants"], list)):
        rows = rows[0]["participants"]

    # Якщо це список елементів, кожен з яких має "participants" — розплющуємо
    if isinstance(rows, list) and rows and isinstance(rows[0], dict) and "participants" in rows[0]:
        flat = []
        for item in rows:
            part = item.get("participants")
            if isinstance(part, list):
                flat.extend(part)
        if flat:
            rows = flat

    # На виході гарантуємо список словників із мінімально потрібними ключами
    norm = []
    if isinstance(rows, list):
        for r in rows:
            if not isinstance(r, dict):
                continue
            norm.append({
                "id": r.get("id", ""),
                "username": r.get("username", ""),
                "text": r.get("text", ""),
                "timestamp": r.get("timestamp", None),
            })
    return norm

def _pick_winners(users, k, seed_str):
    seed = int(hashlib.sha256(seed_str.encode()).hexdigest(), 16) % (2**32)
    rnd = random.Random(seed)
    # стабільна база перед тасуванням
    pool = sorted(
        users,
        key=lambda r: (
            (r.get("username") or "").strip().lower(),
            (r.get("id") or "").strip()
        )
    )
    k = max(0, min(k, len(pool)))
    if k == 0:
        return []
    # детерміноване тасування з використанням seed
    rnd.shuffle(pool)
    # Повертаємо перші k елементів у вигляді списку словників
    return pool[:k]

def _get_job_or_404(job_id):
    job = queue.fetch_job(job_id)
    if not job:
        return None, (jsonify({'error': 'not_found'}), 404)
    return job, None

def _job_http_response(job):
    st = job.get_status()  # queued|started|deferred|finished|failed
    if st == 'finished':
        res = job.result
        if isinstance(res, dict) and 'error' in res:
            code = 400 if res['error'] in ('invalid_post_url', 'login_required') else 500
            return jsonify(res), code
        return jsonify({'participants': res, 'status': st}), 200
    if st == 'failed':
        # не світимо exc_info у проді
        return jsonify({'error': 'internal_error', 'status': st}), 500
    # queued/started/deferred
    return jsonify({'status': st}), 202

@app.route('/api/job_status/<job_id>', methods=['GET', 'OPTIONS'])
def job_status(job_id):
    if request.method == 'OPTIONS':
        return '', 204
    job, err = _get_job_or_404(job_id)
    if err: return err
    return jsonify({'status': job.get_status()}), 200

@app.route('/api/job_result/<job_id>', methods=['GET', 'OPTIONS'])
def job_result(job_id):
    if request.method == 'OPTIONS':
        return '', 204
    job, err = _get_job_or_404(job_id)
    if err: return err
    return _job_http_response(job)

# ── FB Graph endpoints ────────────────────────────────────────────────────────
@app.get("/api/ig/accounts")
def ig_accounts():
    err = _ensure_fb_ready()
    if err:
        return jsonify(err[0]), err[1]
    tok = _require_fb()
    if not tok:
        return jsonify({"error": "login_required", "detail": "fb"}), 401
    try:
        pages = list_pages(tok)
        rows = []
        for p in (pages.get("data") or []):
            ig = (
                p.get("instagram_business_account")
                or p.get("connected_instagram_account")
                or {}
            )
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
        return jsonify({"error": "internal_error", "detail": str(e)}), 500

@app.get("/api/ig/media")
def ig_media_list():
    err = _ensure_fb_ready()
    if err: return jsonify(err[0]), err[1]
    user_tok = _require_fb()
    if not user_tok: return jsonify({"error":"login_required","detail":"fb"}), 401

    ig_user_id = (request.args.get("ig_user_id") or "").strip()
    page_id    = (request.args.get("page_id") or "").strip()
    after      = request.args.get("after")
    if not ig_user_id:
        return jsonify({"error":"validation_error","detail":"ig_user_id required"}), 400

    access_token = user_tok
    # якщо передали page_id — отримаємо page access token
    if page_id:
        try:
            import requests as rq
            GRAPH = "https://graph.facebook.com/v21.0"
            acc = rq.get(f"{GRAPH}/{page_id}",
                         params={"fields":"access_token","access_token":user_tok},
                         timeout=20).json()
            page_tok = acc.get("access_token")
            if page_tok:
                access_token = page_tok
        except Exception:
            pass

    try:
        m = ig_media(ig_user_id, access_token, limit=50, after=after)
        return jsonify(m), 200
    except Exception as e:
        logger.exception("ig_media_list failed")
        return jsonify({"error":"internal_error","detail":str(e)}), 500
    
@app.get("/api/ig/comments")
def ig_comments_list():
    err = _ensure_fb_ready()
    if err: return jsonify(err[0]), err[1]
    user_tok = _require_fb()
    if not user_tok: return jsonify({"error":"login_required","detail":"fb"}), 401

    media_id = (request.args.get("media_id") or "").strip()
    page_id  = (request.args.get("page_id") or "").strip()
    after    = request.args.get("after")
    if not media_id:
        return jsonify({"error":"validation_error","detail":"media_id required"}), 400

    access_token = user_tok
    if page_id:
        try:
            import requests as rq
            GRAPH = "https://graph.facebook.com/v21.0"
            acc = rq.get(f"{GRAPH}/{page_id}",
                         params={"fields":"access_token","access_token":user_tok},
                         timeout=20).json()
            page_tok = acc.get("access_token")
            if page_tok:
                access_token = page_tok
        except Exception:
            pass

    try:
        c = ig_comments(media_id, access_token, limit=100, after=after)
        items = [{
            "id": row.get("id"),
            "username": row.get("username") or "",
            "text": row.get("text") or "",
            "timestamp": row.get("timestamp"),
        } for row in (c.get("data") or [])]
        return jsonify({"participants": items, "paging": c.get("paging")}), 200
    except Exception as e:
        logger.exception("ig_comments failed")
        return jsonify({"error":"internal_error","detail":str(e)}), 500
    
@app.get("/api/ig/comments_all")
def ig_comments_all():
    err = _ensure_fb_ready()
    if err: return jsonify(err[0]), err[1]
    user_tok = _require_fb()
    if not user_tok: return jsonify({"error":"login_required"}), 401

    media_id = (request.args.get("media_id") or "").strip()
    page_id  = (request.args.get("page_id") or "").strip()
    if not media_id: return jsonify({"error":"validation_error","detail":"media_id required"}), 400

    access_token = user_tok
    if page_id:
        acc = rq.get(f"{GRAPH}/{page_id}",
                     params={"fields":"access_token","access_token":user_tok}, timeout=20).json()
        access_token = acc.get("access_token") or user_tok

    out, after = [], None
    max_pages = 2000
    while True:
        r = ig_comments(media_id, access_token, limit=100, after=after)
        items = [{
            "id": row.get("id"),
            "username": row.get("username") or "",
            "text": row.get("text") or "",
            "timestamp": row.get("timestamp"),
        } for row in (r.get("data") or [])]
        out.extend(items)
        after = (((r.get("paging") or {}).get("cursors") or {}).get("after"))
        if not after:
            break
        max_pages -= 1
        if max_pages <= 0:
            logger.warning("ig_comments_all: reached max_pages limit")
            break
        time.sleep(0.2)

    return jsonify({"participants": out, "count": len(out)}), 200

@app.post("/api/ig/comments_filter")
def ig_comments_filter():
    data = request.get_json(silent=True) or {}

    rows = _normalize_participants(data.get("participants"))
    clean = _filter_participants(
        rows,
        required_hashtags=data.get("required_hashtags"),
        min_mentions=int(data.get("min_mentions") or 0),
        started_at=data.get("started_at"),
        ended_at=data.get("ended_at"),
        denylist=data.get("denylist"),
        unique_by=(data.get("unique_by") or "user").lower(),  # <— новий параметр
    )
    return jsonify({"participants": clean, "count": len(clean)}), 200

@app.post("/api/ig/draw")
def ig_draw():
    data = request.get_json(silent=True) or {}
    rows = _normalize_participants(data.get("participants"))
    k = int(data.get("winners") or 1)
    seed = data.get("seed") or f"{time.time_ns()}"
    winners = _pick_winners(rows, k, seed)
    return jsonify({"seed": seed, "winners": winners, "pool_size": len(rows)}), 200

@app.post("/api/ig/run_draw")
def ig_run_draw():
    """
    Тіло JSON:
    {
      "media_id": "18158777950388387",
      "page_id":  "803175646215454",
      "filter": {
        "required_hashtags": [],
        "min_mentions": 0,
        "started_at": null,
        "ended_at": null,
        "denylist": [],
        "unique_by": "user"   # user | comment | both
      },
      "winners": 1,
      "seed": "giveaway-2025-11-24-<media_id>"  # якщо не передали — згенеруємо
    }
    """
    data = request.get_json(silent=True) or {}
    media_id = (data.get("media_id") or "").strip()
    page_id  = (data.get("page_id") or "").strip()
    if not media_id:
        return jsonify({"error":"validation_error","detail":"media_id required"}), 400

    # 1) fetch all
    err = _ensure_fb_ready()
    if err: return jsonify(err[0]), err[1]
    user_tok = _require_fb()
    if not user_tok: return jsonify({"error":"login_required"}), 401

    access_token = user_tok
    if page_id:
        acc = rq.get(f"{GRAPH}/{page_id}",
                     params={"fields":"access_token","access_token":user_tok}, timeout=20).json()
        access_token = acc.get("access_token") or user_tok

    collected, after = [], None
    while True:
        r = ig_comments(media_id, access_token, limit=100, after=after)
        items = [{
            "id": (row.get("id") or "").strip(),
            "username": (row.get("username") or ""),
            "text": row.get("text") or "",
            "timestamp": row.get("timestamp"),
        } for row in (r.get("data") or [])]
        collected.extend(items)
        after = (((r.get("paging") or {}).get("cursors") or {}).get("after"))
        if not after: break
        time.sleep(0.2)

    # 2) filter
    f = (data.get("filter") or {})
    filtered = _filter_participants(
        collected,
        required_hashtags=f.get("required_hashtags"),
        min_mentions=int(f.get("min_mentions") or 0),
        started_at=f.get("started_at"),
        ended_at=f.get("ended_at"),
        denylist=f.get("denylist"),
        unique_by=(f.get("unique_by") or "user").lower(),
    )

    # 3) draw (детерміновано по seed)
    winners_count = int(data.get("winners") or 1)
    seed_str = data.get("seed") or f"giveaway-{int(time.time())}-{media_id}"
    winners = _pick_winners(filtered, winners_count, seed_str)

    # 4) audit/прозорість
    audit = {
        "media_id": media_id,
        "page_id": page_id or None,
        "fetched_count": len(collected),
        "filtered_count": len(filtered),
        "unique_by": (f.get("unique_by") or "user").lower(),
        "seed": seed_str,
        "required_hashtags": f.get("required_hashtags") or [],
        "min_mentions": int(f.get("min_mentions") or 0),
        "started_at": f.get("started_at"),
        "ended_at": f.get("ended_at"),
        "denylist": f.get("denylist") or [],
        # щоб можна було перевірити результат — даємо хеш пулу
        "pool_hash": hashlib.sha256(json.dumps(filtered, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest(),
    }

    return jsonify({
        "audit": audit,
        "pool_size": len(filtered),
        "winners": winners
    }), 200

@app.post("/api/ig/export_csv")
def export_csv():
    rows = (request.get_json(silent=True) or {}).get("participants") or []
    buf = io.StringIO()
    # BOM для Excel
    buf.write("\ufeff")
    w = csv.DictWriter(buf, fieldnames=["username","text","timestamp","id"])
    w.writeheader()
    for r in rows:
        w.writerow({
            "username": r.get("username",""),
            "text": r.get("text",""),
            "timestamp": r.get("timestamp",""),
            "id": r.get("id",""),
        })
    return Response(
        buf.getvalue(),
        mimetype="text/csv; charset=utf-8",
        headers={"Content-Disposition":"attachment; filename=participants.csv"}
    )
# ── Facebook OAuth token exchange ─────────────────────────────────────────────
@app.post("/api/oauth/facebook/token")
def facebook_token():
    data = request.get_json(silent=True) or {}
    code = data.get("code")
    redirect_uri = data.get("redirect_uri")

    if not code or not redirect_uri:
        return jsonify({"error": "bad_request", "detail": "code/redirect_uri required"}), 400

    expected = os.getenv("FB_REDIRECT_URI")
    if expected and redirect_uri != expected:
        return jsonify({"error": "bad_request", "detail": "redirect_uri mismatch"}), 400

    params = {
        "client_id": os.environ["FB_APP_ID"],
        "client_secret": os.environ["FB_APP_SECRET"],
        "redirect_uri": redirect_uri,
        "code": code,
    }

    r = rq.get("https://graph.facebook.com/v20.0/oauth/access_token", params=params, timeout=30)
    try:
        payload = r.json()
    except Exception:
        return jsonify({"error": "graph_bad_response", "text": r.text}), 502

    if r.status_code != 200 or "access_token" not in payload:
        return jsonify({"error": "graph_error", "detail": payload}), r.status_code

    token = payload["access_token"]
    expires_in = int(payload.get("expires_in", 3600))

    _save_fb_tokens(token, expires_in)   # <-- ключове
    return jsonify({"ok": True}), 200

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
            "/api/debug_session",
            "/api/fb/env_debug",
            "/api/fb/login_url",
            "/api/fb/callback",
            "/api/fb/debug_pages",
            "/api/ig/accounts",
            "/api/ig/media?ig_user_id=...",
            "/api/ig/comments?media_id=...",
            "/__routes_dbg",
        ]
    }), 200

# ── Session auth utils (instagrapi by sessionid) ──────────────────────────────
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

@app.route('/api/logout', methods=['POST', 'OPTIONS'])
def logout():
    if request.method == 'OPTIONS':
        return '', 204
    session.clear()
    return jsonify({'ok': True}), 200

# ── Entrypoint ────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 8080)), debug=True)
