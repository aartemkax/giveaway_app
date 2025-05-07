from dotenv import load_dotenv
load_dotenv()
import os
import time
import json
import base64
import requests

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from instagrapi import Client
from instagrapi.exceptions import PleaseWaitFewMinutes, ProxyAddressIsBlocked, BadPassword

app = Flask(__name__, static_folder='static')
CORS(app)

USERNAME        = os.getenv("IG_USERNAME")
PASSWORD        = os.getenv("IG_PASSWORD")
API_BASE_URL    = os.getenv("API_BASE_URL")
SESSION_FILE = None
AVATAR_DIR      = os.path.join(app.static_folder, "avatars")

if not os.path.isdir(AVATAR_DIR):
    os.makedirs(AVATAR_DIR, exist_ok=True)

proxy_url = os.getenv("PROXY_URL")
cl = Client(proxy=proxy_url)

session_b64 = os.getenv("SESSION_JSON_B64")
if session_b64:
    raw = base64.b64decode(session_b64)
    cl.set_settings(json.loads(raw))
    print("✅ Session restored from ENV")
else:
    print("🔵 No session in ENV — login…")
    cl.login(USERNAME, PASSWORD)
    # для локальної зручності:
    cl.dump_settings("session.json")

@app.route("/")
def index():
    return "API is running"

@app.route("/api/avatar/<username>")
def serve_avatar(username):
    path = os.path.join(AVATAR_DIR, f"{username}.jpg")
    if os.path.exists(path):
        return send_from_directory(AVATAR_DIR, f"{username}.jpg")
    return jsonify({"error": "not_found"}), 404

@app.route("/api/fetch_participants", methods=["POST"])
def fetch_participants():
    payload = request.get_json() or {}
    post_url = payload.get("post_url")
    if not post_url:
        return jsonify({"error": "missing_post_url"}), 400

    try:
        media_id = cl.media_pk_from_url(post_url)
        comments = cl.media_comments(media_id, amount=0)

        participants = []
        seen = set()

        for c in comments:
            u = c.user.username
            if u in seen:
                continue
            seen.add(u)

            avatar_url = c.user.profile_pic_url
            local_path = os.path.join(AVATAR_DIR, f"{u}.jpg")
            local_url = f"/api/avatar/{u}?t={int(time.time())}"

            if os.path.exists(local_path) and os.path.getsize(local_path) == 0:
                os.remove(local_path)

            if not os.path.exists(local_path):
                try:
                    r = requests.get(avatar_url, timeout=5)
                    if r.status_code == 200:
                        with open(local_path, "wb") as f:
                            f.write(r.content)
                    else:
                        local_url = "https://i.imgur.com/QCNbOAo.png"
                except Exception:
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
