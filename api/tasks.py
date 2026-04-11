#tasks.py
import logging
import os
import json
import random
import re
import time
import base64

from instagrapi import Client
from instagrapi.exceptions import (
    ChallengeRequired,
    ChallengeUnknownStep,
    ClientJSONDecodeError,
    LoginRequired,
    PleaseWaitFewMinutes,
)
from requests.exceptions import JSONDecodeError as RequestsJSONDecodeError
from redis import Redis
import prometheus_client
from account_affinity import AccountAffinityStore

# регулярка для перевірки Instagram-лінку
URL_PATTERN = re.compile(r"^https?://(www\.)?instagram\.com/(p|reel|reels|tv)/[^/]+/?$")

# Redis для кешу та бот-менеджменту
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
redis_conn = Redis.from_url(redis_url)
affinity_store = AccountAffinityStore(redis_conn)

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


def _classify_fetch_exception(exc: Exception) -> dict:
    message = str(exc)
    message_lower = message.lower()

    if isinstance(exc, PleaseWaitFewMinutes):
        RATE_LIMIT_EXCEPTIONS.inc()
        return {"error": "rate_limited"}

    if isinstance(
        exc,
        (
            ChallengeRequired,
            ChallengeUnknownStep,
            ClientJSONDecodeError,
            RequestsJSONDecodeError,
        ),
    ) or "challenge" in message_lower or "checkpoint" in message_lower:
        CHALLENGE_EXCEPTIONS.inc()
        return {
            "error": "instagram_challenge",
            "detail": "instagram challenge/checkpoint during media fetch",
            "account_status": "challenge",
            "challenge_reason": "worker_media_fetch_challenge",
        }

    if isinstance(exc, LoginRequired):
        return {
            "error": "login_required",
            "detail": "instagram session is no longer valid",
            "account_status": "unverified",
            "challenge_reason": "worker_session_invalid",
        }

    return {"error": "internal_error", "detail": message}

def _restore_client_from_settings(user_settings: dict, proxy: str | None = None) -> Client:
    cl = Client(proxy=proxy)
    cl.delay_range = (2.0, 5.0)
    cl.set_settings(user_settings)

    device_settings = dict(user_settings.get("device_settings") or {})
    if device_settings:
        cl.set_device(device_settings)

    ua = user_settings.get("user_agent") or user_settings.get("device_agent")
    if ua:
        cl.user_agent = ua
        cl.private.headers.update({"User-Agent": ua})
    logging.info(">>> instagrapi client UA=%s proxy=%s", cl.user_agent, "set" if proxy else "none")
    return cl

def _fetch_participants_with_client(cl: Client, post_url: str):
    if not URL_PATTERN.match(post_url):
        return {"error": "invalid_post_url"}

    try:
        media_id = cl.media_pk_from_url(post_url)
    except Exception:
        return {"error": "invalid_post_url"}

    try:
        comments = cl.media_comments(media_id, amount=0)
    except Exception as e:
        logging.exception("Error fetching comments")
        return _classify_fetch_exception(e)

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

def fetch_participants_task(
    settings_b64: str,
    post_url: str,
    use_proxy: bool,
    device_info=None,
    region=None
):
    # Kept for compatibility with existing queue.enqueue callers in api/main.py.
    # Відновлюємо лише сесію без повторної емуляції чи логіну
    try:
        decoded = base64.b64decode(settings_b64)
        user_settings = json.loads(decoded)
    except Exception as e:
        logging.exception("Не вдалося декодувати settings_b64")
        return {"error": "invalid_session_settings"}

    proxy = random.choice(PROXIES) if use_proxy and PROXIES else None
    cl = _restore_client_from_settings(user_settings, proxy=proxy)
    logging.info(">>> fetch task using restored session")
    return _fetch_participants_with_client(cl, post_url)


def fetch_account_participants_task(account_id: str, post_url: str):
    if not affinity_store.acquire_account_lock(account_id, ttl_sec=900):
        return {"error": "account_busy"}

    try:
        context = affinity_store.get_account_context(account_id)
        if not context:
            return {"error": "account_not_found"}

        account = context["account"]
        session_settings = dict(context["session_settings"] or {})
        if not session_settings:
            return {"error": "invalid_session_settings"}

        proxy = context["proxy_url"]
        cl = _restore_client_from_settings(session_settings, proxy=proxy)
        result = _fetch_participants_with_client(cl, post_url)

        if isinstance(result, dict) and result.get("error") == "rate_limited":
            affinity_store.mark_account_result(
                account_id,
                status="cooldown",
                cooldown_until=int(time.time()) + 15 * 60,
            )
        elif isinstance(result, dict) and result.get("error") == "instagram_challenge":
            affinity_store.mark_account_result(
                account_id,
                status="challenge",
                challenge_reason=result.get("challenge_reason") or "worker_media_fetch_challenge",
                cooldown_until=None,
            )
        elif isinstance(result, dict) and result.get("error") == "login_required":
            affinity_store.mark_account_result(
                account_id,
                status="unverified",
                challenge_reason=result.get("challenge_reason") or "worker_session_invalid",
                cooldown_until=None,
            )
        elif isinstance(result, dict) and result.get("error"):
            affinity_store.mark_account_result(
                account_id,
                status=account.status,
                challenge_reason=account.challenge_reason,
                cooldown_until=account.cooldown_until,
            )
        else:
            affinity_store.mark_account_result(
                account_id,
                status="active",
                challenge_reason=None,
                cooldown_until=None,
                last_success=True,
            )
        return result
    finally:
        affinity_store.release_account_lock(account_id)
