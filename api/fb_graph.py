# api/fb_graph.py
import os
import requests
from urllib.parse import urlencode

FB_GRAPH  = "https://graph.facebook.com/v21.0"
FB_OAUTH  = "https://graph.facebook.com/v21.0/oauth"
FB_DIALOG = "https://www.facebook.com/v21.0/dialog/oauth"

APP_ID       = os.getenv("FB_APP_ID")
APP_SECRET   = os.getenv("FB_APP_SECRET")
REDIRECT_URI = os.getenv("FB_REDIRECT_URI")

class FBAuthError(Exception): ...
class FBApiError(Exception): ...

def _require_env():
    if not APP_ID or not APP_SECRET or not REDIRECT_URI:
        missing = []
        if not APP_ID:       missing.append("FB_APP_ID")
        if not APP_SECRET:   missing.append("FB_APP_SECRET")
        if not REDIRECT_URI: missing.append("FB_REDIRECT_URI")
        raise FBAuthError({"error": "missing_fb_env", "detail": ", ".join(missing)})

# ---- OAuth: login URL (FB Login) ----
def login_url(state: str, scopes: list[str]) -> str:
    _require_env()
    q = {
        "client_id": APP_ID,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": " ".join(scopes),
        # щоб FB знову показав діалог і попросив відсутні дозволи
        "auth_type": "rerequest",
        "state": state,
    }
    return f"{FB_DIALOG}/oauth?{urlencode(q)}"

# ---- OAuth: обмін коду на короткоживучий токен (~1h) ----
def exchange_code_for_token(code: str) -> dict:
    _require_env()
    q = {
        "client_id": APP_ID,
        "client_secret": APP_SECRET,
        "redirect_uri": REDIRECT_URI,
        "code": code,
    }
    r = requests.get(f"{FB_OAUTH}/access_token", params=q, timeout=15)
    j = r.json()
    if r.status_code != 200 or "access_token" not in j:
        raise FBAuthError(j)
    return j  # {access_token, token_type, expires_in}

# ---- Обмін на long-lived (~60 днів) ----
def exchange_long_lived(user_token: str) -> dict:
    _require_env()
    q = {
        "grant_type": "fb_exchange_token",
        "client_id": APP_ID,
        "client_secret": APP_SECRET,
        "fb_exchange_token": user_token,
    }
    r = requests.get(f"{FB_OAUTH}/access_token", params=q, timeout=15)
    j = r.json()
    if r.status_code != 200 or "access_token" not in j:
        raise FBAuthError(j)
    return j  # {access_token, token_type, expires_in}

# ---- Graph helpers ----
def me(user_token: str) -> dict:
    r = requests.get(
        f"{FB_GRAPH}/me",
        params={"fields": "id,name,email", "access_token": user_token},
        timeout=15,
    )
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def list_pages(user_token: str) -> dict:
    fields = (
        "id,name,"
        "connected_instagram_account{id,username},"
        "instagram_business_account{id,username}"
    )
    r = requests.get(
        f"{FB_GRAPH}/me/accounts",
        params={"fields": fields, "access_token": user_token},
        timeout=15,
    )
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def ig_media(ig_user_id: str, user_token: str, limit: int = 50, after: str | None = None) -> dict:
    fields = "id,caption,media_type,permalink,timestamp,username"
    params = {"fields": fields, "limit": limit, "access_token": user_token}
    if after:
        params["after"] = after
    r = requests.get(f"{FB_GRAPH}/{ig_user_id}/media", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def ig_comments(media_id: str, user_token: str, limit: int = 100, after: str | None = None) -> dict:
    fields = "id,text,username,timestamp"
    params = {"fields": fields, "limit": limit, "access_token": user_token}
    if after:
        params["after"] = after
    r = requests.get(f"{FB_GRAPH}/{media_id}/comments", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()
