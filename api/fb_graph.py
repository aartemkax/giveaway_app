import os, requests
from urllib.parse import urlencode

GRAPH = "https://graph.facebook.com/v21.0"

# Facebook App (опційно)
FB_APP_ID = os.getenv("FB_APP_ID")
FB_APP_SECRET = os.getenv("FB_APP_SECRET")
FB_REDIRECT_URI = os.getenv("FB_REDIRECT_URI")

# Instagram App (основний для IG Business Login)
IG_APP_ID = os.getenv("IG_APP_ID")
IG_APP_SECRET = os.getenv("IG_APP_SECRET")
IG_REDIRECT_URI = os.getenv("IG_REDIRECT_URI")

class FBAuthError(Exception): ...
class FBApiError(Exception): ...

# -------- Instagram Business Login --------
def ig_login_url(state: str, scopes: list[str]) -> str:
    if not (IG_APP_ID and IG_REDIRECT_URI):
        raise FBAuthError({"error": "missing_ig_env",
                           "detail": "IG_APP_ID/IG_REDIRECT_URI are not set"})
    q = {
        "client_id": IG_APP_ID,
        "redirect_uri": IG_REDIRECT_URI,
        "response_type": "code",
        "scope": " ".join(scopes),
        "state": state,
    }
    return f"https://www.instagram.com/oauth/authorize?{urlencode(q)}"

def ig_exchange_code_for_token(code: str) -> dict:
    q = {
        "client_id": IG_APP_ID,
        "client_secret": IG_APP_SECRET,
        "redirect_uri": IG_REDIRECT_URI,
        "code": code,
    }
    r = requests.get(f"{GRAPH}/oauth/access_token", params=q, timeout=10)
    j = r.json()
    if r.status_code != 200 or "access_token" not in j:
        raise FBAuthError(j)
    return j  # {access_token, token_type, expires_in}

def fb_exchange_long_lived(user_token: str) -> dict:
    q = {
        "grant_type": "fb_exchange_token",
        "client_id": FB_APP_ID,
        "client_secret": FB_APP_SECRET,
        "fb_exchange_token": user_token,
    }
    r = requests.get(f"{GRAPH}/oauth/access_token", params=q, timeout=10)
    j = r.json()
    if r.status_code != 200 or "access_token" not in j:
        raise FBAuthError(j)
    return j

# -------- (опційно) Facebook Login --------
def fb_login_url(state: str, scopes: list[str]) -> str:
    if not (FB_APP_ID and FB_REDIRECT_URI):
        raise FBAuthError({"error": "missing_fb_env",
                           "detail": "FB_APP_ID/FB_REDIRECT_URI are not set"})
    q = {
        "client_id": FB_APP_ID,
        "redirect_uri": FB_REDIRECT_URI,
        "response_type": "code",
        "scope": " ".join(scopes),
        "state": state,
    }
    return f"https://www.facebook.com/v21.0/dialog/oauth?{urlencode(q)}"

def fb_exchange_code_for_token(code: str) -> dict:
    q = {
        "client_id": FB_APP_ID,
        "client_secret": FB_APP_SECRET,
        "redirect_uri": FB_REDIRECT_URI,
        "code": code,
    }
    r = requests.get(f"{GRAPH}/oauth/access_token", params=q, timeout=10)
    j = r.json()
    if r.status_code != 200 or "access_token" not in j:
        raise FBAuthError(j)
    return j

# -------- Graph helpers (спільні) --------
def me(user_token: str) -> dict:
    r = requests.get(f"{GRAPH}/me",
                     params={"fields":"id,name,email", "access_token": user_token},
                     timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def list_pages(user_token: str) -> dict:
    fields = "id,name,connected_instagram_account{id,username},instagram_business_account{id,username}"
    r = requests.get(f"{GRAPH}/me/accounts",
                     params={"fields": fields, "access_token": user_token},
                     timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def ig_media(ig_user_id: str, user_token: str, limit: int = 50, after: str|None = None) -> dict:
    fields = "id,caption,media_type,permalink,timestamp,username"
    params = {"fields": fields, "limit": limit, "access_token": user_token}
    if after: params["after"] = after
    r = requests.get(f"{GRAPH}/{ig_user_id}/media", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def ig_comments(media_id: str, user_token: str, limit: int = 100, after: str|None = None) -> dict:
    fields = "id,text,username,timestamp"
    params = {"fields": fields, "limit": limit, "access_token": user_token}
    if after: params["after"] = after
    r = requests.get(f"{GRAPH}/{media_id}/comments", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()
