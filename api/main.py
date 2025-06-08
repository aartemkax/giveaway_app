import os
import time
import json
import base64
import threading
import random
import requests
import re
from functools import wraps
from flask import current_app, Flask, request, jsonify, send_from_directory, session
from flask_cors import CORS
from flask_session import Session
from instagrapi import Client
from instagrapi.exceptions import (
    PleaseWaitFewMinutes,
    ProxyAddressIsBlocked,
    BadPassword,
    LoginRequired,
    ChallengeRequired,
    ChallengeUnknownStep,
    MediaNotFound,
    MediaUnavailable
)
from dotenv import load_dotenv

# 0) Завантажуємо .env з кореня (для "публічних" констант)
load_dotenv(os.path.join(os.getcwd(), ".env"), override=False)
# 1) Завантажуємо .env з папки api/ (для IG_USERNAME, IG_PASSWORD, SESSION_JSON_B64 тощо)
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"), override=True)

# Регулярка для перевірки Instagram-лінку
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/p/[^/]+/?$")

app = Flask(__name__, static_folder="static")

# 2) SECRET_KEY — обов’язково задайте FLASK_SECRET_KEY у середовищі в Railway!
app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY", "dev-secret-key")

# 3) Налаштування сесійних куків
app.config["SESSION_TYPE"] = "filesystem"
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
# керуємо через ENV — у продакшні задайте SESSION_COOKIE_SECURE=true в Railway
app.config["SESSION_COOKIE_SECURE"] = os.getenv("SESSION_COOKIE_SECURE", "false").lower() == "true"

Session(app)

# Дозволяємо CORS із credentials
CORS(app, supports_credentials=True, resources={r"/api/*": {"origins": "*"}})

# Переконаємося, що папка для аватарок існує
avatars_dir = os.path.join(app.static_folder, "avatars")
os.makedirs(avatars_dir, exist_ok=True)

# Проксі (якщо потрібно)
USE_PROXY = os.getenv("USE_PROXY", "true").lower() == "true"
PROXIES = []

def load_proxy_list():
    try:
        resp = requests.get(
            "https://www.proxy-list.download/api/v1/get?type=https", timeout=10
        )
        return [line.strip() for line in resp.text.splitlines() if ":" in line]
    except:
        return []

def refresh_proxies():
    global PROXIES
    while True:
        new = load_proxy_list()
        if new:
            PROXIES = new
            print(f"🔄 Проксі оновлено: {len(PROXIES)} шт.")
        time.sleep(3600)

if USE_PROXY:
    threading.Thread(target=refresh_proxies, daemon=True).start()
    print("🔄 Proxy rotation enabled")
else:
    print("⚙️ Proxy rotation disabled")

# Фолбек-сесія із ENV (якщо ще немає в session)
raw_b64 = os.getenv("SESSION_JSON_B64", "")
session_env = {}
if raw_b64:
    session_env = json.loads(base64.b64decode("".join(raw_b64.split())))
print("✅ Session settings decoded from ENV")

# Простий кеш
CACHE = {}
CACHE_TTL = 300  # секунди

def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if request.method == "OPTIONS":
            return current_app.make_default_options_response()
        if "ig_settings" not in session:
            return jsonify({"error": "login_required", "detail": "not_logged_in"}), 401
        return f(*args, **kwargs)
    return wrapper

@app.route("/api/login", methods=["POST", "OPTIONS"])
def login():
    if request.method == "OPTIONS":
        return "", 204

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()

    if len(username) < 3 or len(password) < 6:
        return jsonify({"error": "validation_error"}), 400

    try:
        cl = Client()
        cl.login(username, password)
    except BadPassword:
        return jsonify({"error": "invalid_credentials"}), 401
    except LoginRequired:
        return jsonify({"error": "invalid_credentials"}), 401
    except ChallengeRequired:
        return jsonify({"error": "instagram_challenge", "detail": "challenge_required"}), 412
    except ChallengeUnknownStep as e:
        detail = "submit_phone" if "submit_phone" in str(e) else "unknown_step"
        return jsonify({"error": "instagram_challenge", "detail": detail}), 412
    except Exception:
        return jsonify({"error": "internal_error"}), 500

    session["ig_settings"] = cl.get_settings()
    return jsonify({"status": "ok"}), 200

@app.route("/api/debug_session", methods=["GET"])
def debug_session():
    return jsonify({
        "session_keys": list(session.keys()),
        "ig_settings_present": "ig_settings" in session
    })

@app.route("/api/avatar/<username>")
def serve_avatar(username):
    path = os.path.join(avatars_dir, f"{username}.jpg")
    if os.path.isfile(path):
        return send_from_directory(avatars_dir, f"{username}.jpg")
    return jsonify({"error": "not_found"}), 404

@app.route("/api/fetch_participants", methods=["POST", "OPTIONS"])
@login_required
def fetch_participants():
    if request.method == "OPTIONS":
        return "", 204

    data = request.get_json() or {}
    post_url = (data.get("post_url") or "").strip()
    if not URL_PATTERN.match(post_url):
        return jsonify({"error": "invalid_post_url"}), 400

    cl = Client(proxy=random.choice(PROXIES) if USE_PROXY and PROXIES else None)
    cl.set_settings(session.get("ig_settings") or session_env)

    try:
        media_id = cl.media_pk_from_url(post_url)
    except (MediaNotFound, MediaUnavailable):
        return jsonify({"error": "invalid_post_url"}), 400

    if media_id in CACHE and time.time() - CACHE[media_id][1] < CACHE_TTL:
        return jsonify({"participants": CACHE[media_id][0]}), 200

    try:
        comments = cl.media_comments(media_id, amount=0)
    except PleaseWaitFewMinutes:
        return jsonify({"error": "rate_limited"}), 429
    except ProxyAddressIsBlocked:
        return jsonify({"error": "proxy_blocked"}), 403
    except LoginRequired:
        return jsonify({"error": "login_required", "detail": "session_expired"}), 401
    except BadPassword:
        return jsonify({"error": "invalid_credentials"}), 401
    except (MediaNotFound, MediaUnavailable):
        return jsonify({"error": "invalid_post_url"}), 400

    participants, seen = [], set()
    for c in comments:
        u = c.user.username
        if u in seen:
            continue
        seen.add(u)

        avatar_url = c.user.profile_pic_url
        local_file = os.path.join(avatars_dir, f"{u}.jpg")
        local_url = f"/api/avatar/{u}?t={int(time.time())}"
        try:
            r = requests.get(avatar_url, timeout=5)
            if r.status_code == 200:
                with open(local_file, "wb") as f:
                    f.write(r.content)
            else:
                local_url = "https://i.imgur.com/QCNbOAo.png"
        except:
            local_url = "https://i.imgur.com/QCNbOAo.png"

        participants.append({"username": u, "profile_pic_url": local_url})

    CACHE[media_id] = (participants, time.time())
    return jsonify({"participants": participants}), 200

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    # Локально слухаємо на 0.0.0.0, але в продакшні це керує Gunicorn
    app.run(host="0.0.0.0", port=port, debug=True)
