# api/main.py

import os
import time
import json
import base64
import threading
import logging
import random
import requests
import re

from flask import Flask, request, jsonify, session
from flask_cors import CORS
from flask_session import Session
from redis import Redis
from rq import Queue
from tasks import fetch_participants_task
from functools import wraps
from instagrapi.exceptions import (
    BadPassword,
    LoginRequired,
    ChallengeRequired,
    ChallengeUnknownStep
)
from instagrapi import Client
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO)

# ————— Proxy rotation —————
USE_PROXY = os.getenv("USE_PROXY", "true").lower() == "true"
PROXIES = []

def load_proxy_list():
    try:
        resp = requests.get(
            "https://www.proxy-list.download/api/v1/get?type=https", timeout=10
        )
        return [line.strip() for line in resp.text.splitlines() if ":" in line]
    except Exception:
        logging.warning("Не вдалося завантажити проксі")
        return []

def refresh_proxies():
    global PROXIES
    while True:
        new = load_proxy_list()
        if new:
            PROXIES = new
            logging.info(f"🔄 Проксі оновлено: {len(PROXIES)} шт.")
        time.sleep(3600)

if USE_PROXY:
    threading.Thread(target=refresh_proxies, daemon=True).start()
    logging.info("🔄 Proxy rotation enabled")
else:
    logging.info("⚙️ Proxy rotation disabled")

# ————— Environment —————
load_dotenv(os.path.join(os.getcwd(), ".env"), override=False)
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"), override=True)

app = Flask(__name__, static_folder="static")
app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY", "dev-secret-key")
app.config["SESSION_TYPE"] = "filesystem"
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = os.getenv("SESSION_COOKIE_SECURE", "false").lower() == "true"
Session(app)
CORS(app, supports_credentials=True, resources={r"/api/*": {"origins": "*"}})

# ————— RQ / Redis setup —————
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
redis_conn = Redis.from_url(redis_url)
queue = Queue(connection=redis_conn)

# ————— Helpers —————
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/p/[^/]+/?$")

def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if "ig_settings" not in session:
            return jsonify({"error": "login_required"}), 401
        return f(*args, **kwargs)
    return wrapper

# ————— LOGIN —————
@app.route("/api/login", methods=["POST", "OPTIONS"])
def login():
    if request.method == "OPTIONS":
        return "", 204
    data = request.get_json(force=True)
    user, pwd = data.get("username", "").strip(), data.get("password", "").strip()
    if len(user) < 3 or len(pwd) < 6:
        return jsonify({"error": "validation_error"}), 400

    cl = Client()
    # Забираємо input() при challenge
    cl.change_password_handler = lambda u: (_ for _ in ()).throw(ChallengeRequired("challenge"))
    try:
        cl.login(user, pwd)
    except BadPassword | LoginRequired:
        return jsonify({"error": "invalid_credentials"}), 401
    except ChallengeRequired:
        return jsonify({"error": "instagram_challenge"}), 412
    except Exception as e:
        logging.exception("Login failed")
        return jsonify({"error": "internal_error", "detail": str(e)}), 500

    session["ig_settings"] = cl.get_settings()
    return jsonify({"status": "ok"}), 200

# ————— ASYNC FETCH —————
@app.route("/api/fetch_participants_async", methods=["POST", "OPTIONS"])
@login_required
def fetch_async():
    if request.method == "OPTIONS":
        return "", 204
    data = request.get_json(force=True)
    url = data.get("post_url", "").strip()
    if not URL_PATTERN.match(url):
        return jsonify({"error": "invalid_post_url"}), 400

    settings_b64 = base64.b64encode(json.dumps(session["ig_settings"]).encode()).decode()
    use_proxy = USE_PROXY

    job = queue.enqueue(
        fetch_participants_task,
        settings_b64,
        url,
        use_proxy,
        job_timeout=600  # 10 хвилин
    )
    return jsonify({"job_id": job.id}), 202

@app.route("/api/job_status/<job_id>")
@login_required
def job_status(job_id):
    job = queue.fetch_job(job_id)
    if not job:
        return jsonify({"error": "not_found"}), 404
    return jsonify({"status": job.get_status()}), 200

@app.route("/api/job_result/<job_id>")
@login_required
def job_result(job_id):
    job = queue.fetch_job(job_id)
    if not job:
        return jsonify({"error": "not_found"}), 404
    if job.is_finished:
        return jsonify({"participants": job.result}), 200
    if job.is_failed:
        return jsonify({"error": "internal_error", "detail": str(job.exc_info)}), 500
    return jsonify({"status": job.get_status()}), 202

@app.route("/api/debug_session", methods=["GET"])
def debug_session():
    return jsonify({
        "session_keys": list(session.keys()),
        "ig_settings_present": "ig_settings" in session
    })

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)