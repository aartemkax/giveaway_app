from dotenv import load_dotenv
load_dotenv()
import os
import time
import requests

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from instagrapi import Client

app = Flask(__name__, static_folder='static')
CORS(app)

# ← зчитуємо з середовища
USERNAME      = os.getenv("IG_USERNAME")
PASSWORD      = os.getenv("IG_PASSWORD")
API_BASE_URL  = os.getenv("API_BASE_URL")
SESSION_FILE  = "settings.json"
AVATAR_DIR    = os.path.join(app.static_folder, "avatars")

# … код створення AVATAR_DIR …

# 🔐 Сесія Instagrapi з проксі
proxy_url = os.getenv("PROXY_URL")    # наприклад "http://34.102.48.89:8080"
cl = Client(proxy=proxy_url)

if os.path.exists(SESSION_FILE):
    cl.load_settings(SESSION_FILE)
    try:
        cl.get_timeline_feed()
        print("✅ Сесія активна")
    except Exception:
        print("⚠️ Сесія недійсна. Перелогінюємось...")
        cl.login(USERNAME, PASSWORD)
        cl.dump_settings(SESSION_FILE)
else:
    print("🔵 Немає сесії. Логін...")
    cl.login(USERNAME, PASSWORD)
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
        # Якщо нема — повернемо запасну
        return jsonify({"error": "Avatar not found"}), 404

@app.route("/api/fetch_participants", methods=["POST"])
def fetch_participants():
    data = request.get_json()
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

            avatar_url = str(comment.user.profile_pic_url)
            avatar_path = os.path.join(AVATAR_DIR, f"{username}.jpg")
            # тепер віддаємо через новий ендпоінт і додаємо timestamp
            local_url = f"/api/avatar/{username}?t={int(time.time())}"

            # 🛠️ Якщо файл існує, але порожній — видалити
            if os.path.exists(avatar_path) and os.path.getsize(avatar_path) == 0:
                os.remove(avatar_path)

            # якщо файлу ще нема — завантажуємо
            if not os.path.exists(avatar_path):
                try:
                    response = requests.get(avatar_url, timeout=5)
                    if response.status_code == 200:
                        with open(avatar_path, "wb") as f:
                            f.write(response.content)
                        print(f"💾 Збережено аватар для @{username}")
                    else:
                        print(f"⚠️ Помилка при завантаженні ({response.status_code})")
                        local_url = "https://i.imgur.com/QCNbOAo.png"
                except Exception as e:
                    print(f"❌ Помилка скачування: {e}")
                    local_url = "https://i.imgur.com/QCNbOAo.png"

            participants.append({
                "username": username,
                "profile_pic_url": local_url
            })

        return jsonify({"participants": participants})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)