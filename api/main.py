# api/main.py

from dotenv import load_dotenv
import threading
import random
import requests
import os
import time
import json
import base64

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from instagrapi import Client
from instagrapi.exceptions import PleaseWaitFewMinutes, ProxyAddressIsBlocked, BadPassword

load_dotenv()  # за замовчуванням читає .env в тій же папці або вище

app = Flask(__name__, static_folder="static")
CORS(app)

USERNAME     = os.getenv("IG_USERNAME")
PASSWORD     = os.getenv("IG_PASSWORD")
API_BASE_URL = os.getenv("API_BASE_URL")
AVATAR_DIR   = os.path.join(app.static_folder, "avatars")

os.makedirs(AVATAR_DIR, exist_ok=True)

# --- ПРОКСІ РОТАЦІЯ (як раніше) ---

PROXIES: list[str] = []

def load_proxy_list() -> list[str]:
    try:
        resp = requests.get("https://www.proxy-list.download/api/v1/get?type=https", timeout=10)
        return [line.strip() for line in resp.text.splitlines() if ":" in line]
    except:
        return []

def refresh_proxies_periodically(interval_sec: int = 3600):
    def runner():
        global PROXIES
        while True:
            new = load_proxy_list()
            if new:
                PROXIES = new
                print(f"🔄 Проксі оновлено: {len(PROXIES)} шт.")
            time.sleep(interval_sec)
    threading.Thread(target=runner, daemon=True).start()

refresh_proxies_periodically()

# --- СЕСІЯ INSTAGRAPI ---

raw_b64 = os.getenv("SESSION_JSON_B64", "")
# прибираємо зайві пробіли та нові рядки
b64 = "".join(raw_b64.split())
if not b64:
    raise RuntimeError("Не знайдено SESSION_JSON_B64 в оточенні")

try:
    decoded = base64.b64decode(b64)
    session_settings = json.loads(decoded)
    print("✅ Session settings decoded from ENV")
except Exception as e:
    raise RuntimeError(f"Помилка декодування SESSION_JSON_B64: {e}")

# --- РОУТИ ---

@app.route("/")
def index():
    return "API is running"

@app.route("/api/avatar/<username>")
def serve_avatar(username):
    path = os.path.join(AVATAR_DIR, f"{username}.jpg")
    if os.path.isfile(path):
        return send_from_directory(AVATAR_DIR, f"{username}.jpg")
    return jsonify({"error": "not_found"}), 404

@app.route("/api/fetch_participants", methods=["POST"])
def fetch_participants():
    data = request.get_json() or {}
    post_url = data.get("post_url")
    if not post_url:
        return jsonify({"error": "missing_post_url"}), 400

    proxy = random.choice(PROXIES) if PROXIES else None
    print(f"▶️ Using proxy: {proxy}")

    cl = Client(proxy=proxy)
    cl.set_settings(session_settings)

    try:
        media_id = cl.media_pk_from_url(post_url)
        comments = cl.media_comments(media_id, amount=0)

        participants, seen = [], set()
        for c in comments:
            u = c.user.username
            if u in seen: continue
            seen.add(u)

            avatar_url = c.user.profile_pic_url
            local_file = os.path.join(AVATAR_DIR, f"{u}.jpg")
            local_url  = f"/api/avatar/{u}?t={int(time.time())}"

            if os.path.exists(local_file) and os.path.getsize(local_file) == 0:
                os.remove(local_file)
            if not os.path.exists(local_file):
                try:
                    r = requests.get(avatar_url, timeout=5)
                    if r.status_code == 200:
                        with open(local_file, "wb") as f:
                            f.write(r.content)
                    else:
                        local_url = "https://i.imgur.com/QCNbOAo.png"
                except:
                    local_url = "https://i.imgur.com/QCNbOAo.png"

            participants.append({
                "username": u,
                "profile_pic_url": local_url
            })

        return jsonify({"participants": participants}), 200

    except PleaseWaitFewMinutes:
        return jsonify({"error": "rate_limited"}), 429
    except ProxyAddressIsBlocked:
        return jsonify({"error": "proxy_blocked"}), 403
    except BadPassword:
        return jsonify({"error": "invalid_credentials"}), 401
    except Exception as e:
        return jsonify({"error": "internal_error", "detail": str(e)}), 500

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
