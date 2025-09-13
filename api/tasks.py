# api/tasks.py
import os
import re
import json
import time
import base64
import random
import logging

from redis import Redis
from instagrapi import Client
from instagrapi.exceptions import (
    LoginRequired,
    ChallengeRequired,
    PleaseWaitFewMinutes,
    MediaNotFound,
)

import prometheus_client
from prometheus_client import Summary, Counter

# ──────────────────────────────────────────────────────────────────────────────
# Конфіг
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/p/[^/]+/?$")

redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
redis_conn = Redis.from_url(redis_url)

CACHE_TTL = int(os.getenv("CACHE_TTL", "3600"))          # сек, кеш коментарів
MAX_COMMENTS = int(os.getenv("MAX_COMMENTS", "0"))       # 0 = всі (instagrapi)
LOCK_WAIT_SEC = float(os.getenv("LOCK_WAIT_SEC", "10"))  # скільки чекати кеш після чужого лока

# Проксі (опційно)
try:
    from main import PROXIES
except ImportError:
    PROXIES = []

# Логи
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("tasks")
logging.getLogger("instagrapi").setLevel(logging.INFO)

# ──────────────────────────────────────────────────────────────────────────────
# Метрики Prometheus
RATE_LIMIT_EXC = prometheus_client.Counter(
    "instagrapi_rate_limit_exceptions_total", "Rate limit hits"
)
CHALLENGE_EXC = prometheus_client.Counter(
    "instagrapi_challenge_exceptions_total", "Instagram challenge hits"
)
CACHE_HITS = prometheus_client.Counter(
    "participants_cache_hits_total", "Cache hits for comments"
)
CACHE_MISSES = prometheus_client.Counter(
    "participants_cache_misses_total", "Cache misses for comments"
)

JOB_DURATION = Summary(
    "participants_job_duration_seconds", "Duration of fetch_participants_task"
)
JOB_ERRORS = Counter(
    "participants_job_errors_total", "Errors by type", ["type"]
)
JOB_SOURCE = Counter(
    "participants_job_source_total", "Source of participants", ["source"]  # cache|instagram
)

# ──────────────────────────────────────────────────────────────────────────────
@JOB_DURATION.time()
def fetch_participants_task(
    settings_b64: str,
    post_url: str,
    use_proxy: bool,
    device_info=None,
    region=None,
):
    """
    Повертає унікальних учасників (username + avatar) з коментарів поста.
    Логін НЕ виконується — використовуються settings, передані із веб-сесії.
    """

    # 1) Відновлюємо settings
    try:
        decoded = base64.b64decode(settings_b64)
        user_settings = json.loads(decoded)
    except Exception:
        logger.exception("Не вдалося декодувати settings_b64")
        JOB_ERRORS.labels("invalid_session_settings").inc()
        return {"error": "invalid_session_settings"}

    proxy = random.choice(PROXIES) if use_proxy and PROXIES else None
    cl = Client(proxy=proxy)
    cl.delay_range = (2.0, 5.0)
    cl.set_settings(user_settings)

    ua = user_settings.get("user_agent")
    if ua:
        cl.user_agent = ua
        cl.private.headers.update({"User-Agent": ua})
    logger.info("fetch: UA=%s proxy=%s", cl.user_agent, proxy is not None)

    # 2) Валідація URL і отримання media_id
    if not URL_PATTERN.match(post_url or ""):
        return {"error": "invalid_post_url"}
    try:
        media_id = cl.media_pk_from_url(post_url)
    except Exception:
        return {"error": "invalid_post_url"}

    cache_key = f"ig:comments:{media_id}"
    lock_key = f"ig:lock:{media_id}"
    ttl = CACHE_TTL

    # 3) Спроба прочитати з кешу
    items = None
    cached = redis_conn.get(cache_key)
    if cached:
        try:
            items = json.loads(cached)  # [{"u":..., "p":...}, ...]
            CACHE_HITS.inc()
            JOB_SOURCE.labels("cache").inc()
            logger.info("fetch: cache HIT media_id=%s", media_id)
        except Exception:
            items = None

    # 4) Якщо кеша нема — намагаємось повісити lock, щоб один воркер тягнув IG
    if items is None:
        CACHE_MISSES.inc()
        # setnx lock на короткий час
        got_lock = bool(redis_conn.set(lock_key, "1", nx=True, ex=int(max(LOCK_WAIT_SEC, 1))))
        if not got_lock:
            # Хтось інший уже тягне IG: почекаємо, поки з’явиться кеш
            logger.info("fetch: waiting for cache (lock held) media_id=%s", media_id)
            deadline = time.time() + LOCK_WAIT_SEC
            while time.time() < deadline:
                time.sleep(0.5)
                cached = redis_conn.get(cache_key)
                if cached:
                    try:
                        items = json.loads(cached)
                        CACHE_HITS.inc()
                        JOB_SOURCE.labels("cache").inc()
                        break
                    except Exception:
                        pass

        # 5) Якщо все ще нема — тягнемо з Instagram
        if items is None:
            logger.info("fetch: cache MISS -> IG fetch media_id=%s", media_id)
            try:
                comments = cl.media_comments(media_id, amount=MAX_COMMENTS)
            except PleaseWaitFewMinutes:
                RATE_LIMIT_EXC.inc()
                JOB_ERRORS.labels("rate_limited").inc()
                return {"error": "rate_limited"}
            except LoginRequired:
                JOB_ERRORS.labels("login_required").inc()
                return {"error": "login_required"}
            except ChallengeRequired:
                CHALLENGE_EXC.inc()
                JOB_ERRORS.labels("instagram_challenge").inc()
                return {"error": "instagram_challenge"}
            except MediaNotFound:
                JOB_ERRORS.labels("post_unavailable").inc()
                return {"error": "post_unavailable"}
            except Exception as e:
                logger.exception("Error fetching comments")
                JOB_ERRORS.labels("internal_error").inc()
                return {"error": "internal_error", "detail": str(e)}

            # нормалізуємо
            items = [
                {"u": c.user.username, "p": str(c.user.profile_pic_url)}
                for c in comments
            ]
            JOB_SOURCE.labels("instagram").inc()

            # кладемо в кеш
            try:
                redis_conn.setex(cache_key, ttl, json.dumps(items))
            except Exception:
                logger.exception("Не вдалося записати кеш у Redis")
            finally:
                # знімаємо lock, якщо це ми його ставили
                try:
                    redis_conn.delete(lock_key)
                except Exception:
                    pass

    # 6) Формуємо унікальних учасників
    participants, seen = [], set()
    for it in (items or []):
        u = it.get("u")
        if not u:
            continue
        if u not in seen:
            seen.add(u)
            participants.append({"username": u, "profile_pic_url": it.get("p", "")})

    return participants
