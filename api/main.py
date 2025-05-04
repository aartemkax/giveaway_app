from dotenv import load_dotenv
import os
import time
import requests
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from instagrapi import Client

# Локально підвантажуємо .env-файл, в продакшні він ігнорується
if os.path.exists(".env"):
    load_dotenv()

# Змінні середовища
USERNAME      = os.getenv("IG_USERNAME")
PASSWORD      = os.getenv("IG_PASSWORD")
PROXY_URL     = os.getenv("PROXY_URL")        # за потреби
SESSION_FILE  = os.path.join("api", "session.json")
AVATAR_DIR    = os.path.join("static", "avatars")

app = Flask(__name__, static_folder="static")
CORS(app)

# ➡️ Створюємо папку для аватарів, якщо нема
os.makedirs(AVATAR_DIR, exist_ok=True)

# ─── Ініціалізуємо Instagram-клієнт з проксі (якщо вказано) ───
cl = Client(proxy=PROXY_URL) if PROXY_URL else Client()

# ─── Спроба завантажити сесію ─────────────────────────────────
if os.path.exists(SESSION_FILE):
    try:
        cl.load_settings(SESSION_FILE)
        # пробуємо зробити запит, щоб перевірити чи сесія дійсна
        cl.get_timeline_feed()
        print("✅ Сесія завантажена з", SESSION_FILE)
    except Exception:
        print("⚠️ Сесія недійсна. Перелогінюємось...")
        cl.login(USERNAME, PASSWORD)
        cl.dump_settings(SESSION_FILE)
        print("💾 Нова сесія збережена в", SESSION_FILE)
else:
    print("🔵 Файлу сесії нема — логін...")
    cl.login(USERNAME, PASSWORD)
    cl.dump_settings(SESSION_FILE)
    print("💾 Сесія збережена в", SESSION_FILE)

# ─── Здоров’я сервісу ────────────────────────────────────────────
@app.route("/")
def index():
    return "🎯 API працює! Готовий приймати запити.", 200

# ─── Віддача аватарки ────────────────────────────────────────────
@app.route("/api/avatar/<username>")
def serve_avatar(username):
    filename = f"{username}.jpg"
    path = os.path.join(AVATAR_DIR, filename)
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return send_from_directory(AVATAR_DIR, filename)
    return jsonify({"error": "Avatar not found"}), 404

# ─── Головний функціонал ────────────────────────────────────────
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
            u = comment.user.username
            if u in seen:
                continue
            seen.add(u)

            avatar_url  = comment.user.profile_pic_url
            avatar_path = os.path.join(AVATAR_DIR, f"{u}.jpg")
            local_url   = f"/api/avatar/{u}?t={int(time.time())}"

            # якщо нема або пошкоджений файл — завантажуємо заново
            if not os.path.exists(avatar_path) or os.path.getsize(avatar_path) == 0:
                try:
                    r = requests.get(avatar_url, timeout=5)
                    r.raise_for_status()
                    with open(avatar_path, "wb") as f:
                        f.write(r.content)
                    print("💾 Avatar saved for", u)
                except Exception as e:
                    print("❌ Error downloading avatar for", u, e)
                    local_url = "https://i.imgur.com/QCNbOAo.png"

            participants.append({
                "username": u,
                "profile_pic_url": local_url
            })

        return jsonify({"participants": participants})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ─── Запуск локально ─────────────────────────────────────────────
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)), debug=True)
