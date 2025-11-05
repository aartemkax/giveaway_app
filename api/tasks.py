#tasks.py
import logging
import os
import json
import random
import re
import time
import base64
from datetime import datetime

from instagrapi import Client
from instagrapi.exceptions import (
    LoginRequired,
    ChallengeRequired,
    MediaNotFound,
    PleaseWaitFewMinutes
)
from redis import Redis
import prometheus_client
from device_emulator import emulate_device  # додано емулювання пристрою

# регулярка для перевірки Instagram-лінку
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/(p|reel|tv)/[^/]+/?$")

# Redis для кешу та бот-менеджменту
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
redis_conn = Redis.from_url(redis_url)

# Директорія з JSON-сесіями ботів
BOT_SESSIONS_DIR = os.path.join(os.path.dirname(__file__), "bot_sessions")
os.makedirs(BOT_SESSIONS_DIR, exist_ok=True)
bot_files = [f for f in os.listdir(BOT_SESSIONS_DIR) if f.endswith('.json')]

# Інші конфіги
PAGE_SIZE = int(os.getenv("PAGE_SIZE", "20"))
CACHE_TTL = int(os.getenv("CACHE_TTL", "3600"))  # секунди

# Проксі (опційно)
try:
    from main import PROXIES
except ImportError:
    PROXIES = []

# Метрики Prometheus
RATE_LIMIT_EXCEPTIONS = prometheus_client.Counter(
    'instagrapi_rate_limit_exceptions', 'Rate limit hits'
)
CHALLENGE_EXCEPTIONS = prometheus_client.Counter(
    'instagrapi_challenge_exceptions', 'Instagram challenge hits'
)

logging.basicConfig(level=logging.INFO)
logging.getLogger("instagrapi").setLevel(logging.INFO)

def fetch_participants_task(
    settings_b64: str,
    post_url: str,
    use_proxy: bool,
    device_info=None,
    region=None
):
    # Відновлюємо лише сесію без повторної емуляції чи логіну
    try:
        decoded = base64.b64decode(settings_b64)
        user_settings = json.loads(decoded)
    except Exception as e:
        logging.exception("Не вдалося декодувати settings_b64")
        return {"error": "invalid_session_settings"}

    proxy = random.choice(PROXIES) if use_proxy and PROXIES else None
    cl = Client(proxy=proxy)
    cl.delay_range = (2.0, 5.0)

    # Встановлюємо налаштування сесії
    cl.set_settings(user_settings)
    ua = user_settings.get("user_agent")
    if ua:
        cl.user_agent = ua
        cl.private.headers.update({"User-Agent": ua})
    logging.info(">>> fetch таск використовує UA=%s", cl.user_agent)

    # Валідація URL
    if not URL_PATTERN.match(post_url):
        return {"error": "invalid_post_url"}

    # Отримуємо media_id
    try:
        media_id = cl.media_pk_from_url(post_url)
    except Exception:
        return {"error": "invalid_post_url"}

    # Завантажуємо всі коментарі одним запитом
    try:
        comments = cl.media_comments(media_id, amount=0)
    except PleaseWaitFewMinutes:
        RATE_LIMIT_EXCEPTIONS.inc()
        return {"error": "rate_limited"}
    except Exception as e:
        logging.exception("Error fetching comments")
        return {"error": "internal_error", "detail": str(e)}

    # Формуємо унікальний список учасників
    participants = []
    seen = set()
    for c in comments:
        uname = c.user.username
        if uname not in seen:
            seen.add(uname)
            participants.append({
                "username": uname,
                "profile_pic_url": str(c.user.profile_pic_url)
            })


    return participants
