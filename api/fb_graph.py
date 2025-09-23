# api/fb_graph.py
import os, requests
from urllib.parse import urlencode

API_VER = "v21.0"  # <— єдина версія для dialog і graph
FB_GRAPH = f"https://graph.facebook.com/{API_VER}"
FB_DIALOG = f"https://www.facebook.com/{API_VER}/dialog/oauth"

APP_ID = os.getenv("FB_APP_ID")
APP_SECRET = os.getenv("FB_APP_SECRET")
REDIRECT_URI = os.getenv("FB_REDIRECT_URI")

class FBAuthError(Exception): ...
class FBApiError(Exception): ...

def login_url(state: str, scopes: list[str]) -> str:
    q = {
        "client_id": APP_ID,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": ",".join(scopes),      # <— коми
        "state": state,
    }
    return f"{FB_DIALOG}?{urlencode(q)}"

def exchange_code_for_token(code: str) -> dict:
    params = {
        "client_id": APP_ID,
        "client_secret": APP_SECRET,
        "redirect_uri": REDIRECT_URI,
        "code": code,
    }
    r = requests.get(f"{FB_GRAPH}/oauth/access_token", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBAuthError(r.json())
    return r.json()  # {access_token, token_type, expires_in}

def exchange_long_lived(user_token: str) -> dict:
    params = {
        "grant_type": "fb_exchange_token",
        "client_id": APP_ID,
        "client_secret": APP_SECRET,
        "fb_exchange_token": user_token,
    }
    r = requests.get(f"{FB_GRAPH}/oauth/access_token", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBAuthError(r.json())
    return r.json()  # {access_token, token_type, expires_in}

def me(user_token: str) -> dict:
    r = requests.get(f"{FB_GRAPH}/me",
                     params={"fields":"id,name,email", "access_token": user_token},
                     timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def list_pages(user_token: str) -> dict:
    fields = "id,name,instagram_business_account{id,username}"
    r = requests.get(f"{FB_GRAPH}/me/accounts",
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
    r = requests.get(f"{FB_GRAPH}/{ig_user_id}/media", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()

def ig_comments(media_id: str, user_token: str, limit: int = 100, after: str|None = None) -> dict:
    fields = "id,text,username,timestamp"
    params = {"fields": fields, "limit": limit, "access_token": user_token}
    if after: params["after"] = after
    r = requests.get(f"{FB_GRAPH}/{media_id}/comments", params=params, timeout=15)
    try:
        r.raise_for_status()
    except requests.HTTPError:
        raise FBApiError(r.json())
    return r.json()
