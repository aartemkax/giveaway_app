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

app = Flask(__name__, static_folder='static')
CORS(app)

# ← зчитуємо з середовища
USERNAME     = os.getenv("IG_USERNAME")
PASSWORD     = os.getenv("IG_PASSWORD")
API_BASE_URL = os.getenv("API_BASE_URL")
# під шлях до локального файлу сесії (якщо захочете зберігати файл)
SESSION_FILE = os.path.join("api", "session.json")
AVATAR_DIR   = os.path.join(app.static_folder, "avatars")

# 🔧 Переконаємося, що каталог аватарів існує
if not os.path.isdir(AVATAR_DIR):
    os.makedirs(AVATAR_DIR, exist_ok=True)

# Ініціалізуємо клієнт Instagrapi (за потреби з проксі)
proxy_url = os.getenv("PROXY_URL")
cl = Client(proxy=proxy_url)

# Спроба відновити сесію з ENV змінної SESSION_JSON_B64
session_b64 = os.getenv("SESSION_JSON_B64")
if session_b64:
    raw = base64.b64decode(session_b64)
    settings = json.loads(raw)
    cl.set_settings(settings)
    print("✅ Session restored from ENV")
elif os.path.exists(SESSION_FILE):
    cl.load_settings(SESSION_FILE)
    print("✅ Session loaded from file")
else:
    print("🔵 No session found — logging in")
    cl.login(USERNAME, PASSWORD)
    # зберігаємо на диск для локального запуску
    cl.dump_settings(SESSION_FILE)

@app.route("/")
def index():
    return "🎯 API працює! Готовий приймати запити."

# Новий маршрут для віддачі аватарок
@app.route("/api/avatar/<username>")
def serve_avatar(username):
    filename = f"{username}.jpg"
    file_path = os.path.join(AVATAR_DIR, filename)

    if os.path.exists(file_path):
        return send_from_directory(AVATAR_DIR, filename)
    else:
        return jsonify({"error": "Avatar not found"}), 404

# Основний ендпоінт для отримання учасників
@app.route("/api/fetch_participants", methods=["POST"])
def fetch_participants():
    data = request.get_json() or {}
    post_url = data.get("post_url")

    if not post_url:
        return jsonify({"error": "Не вказано post_url"}), 400

    try:
        media_id = cl.media_pk_from_url(post_url)
        comments = cl.media_comments(media_id, amount=0)

        participants = []
        seen = set()

        for comment in comments:
            username = comment.user.username
            if username in seen:
                continue
            seen.add(username)

            avatar_url = comment.user.profile_pic_url
            avatar_path = os.path.join(AVATAR_DIR, f"{username}.jpg")
            local_url = f"/api/avatar/{username}?t={int(time.time())}"

            # якщо файл порожній — видалити
            if os.path.exists(avatar_path) and os.path.getsize(avatar_path) == 0:
                os.remove(avatar_path)

            # завантажити, якщо нема
            if not os.path.exists(avatar_path):
                try:
                    resp = requests.get(avatar_url, timeout=5)
                    if resp.status_code == 200:
                        with open(avatar_path, 'wb') as f:
                            f.write(resp.content)
                        print(f"💾 Saved avatar for @{username}")
                    else:
                        print(f"⚠️ Error downloading avatar: {{resp.status_code}}")
                        local_url = "https://i.imgur.com/QCNbOAo.png"
                except Exception as e:
                    print(f"❌ Download error: {{e}}")
                    local_url = "https://i.imgur.com/QCNbOAo.png"

            participants.append({
                "username": username,
                "profile_pic_url": local_url
            })

        return jsonify({"participants": participants})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
