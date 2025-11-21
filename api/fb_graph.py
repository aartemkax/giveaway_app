# api/fb_graph.py
import os
import urllib.parse as up
import requests as rq

GRAPH = "https://graph.facebook.com/v21.0"

def _appid(): return os.environ["FB_APP_ID"]
def _secret(): return os.environ["FB_APP_SECRET"]
def _redirect(): return os.environ["FB_REDIRECT_URI"]

def login_url(state: str, scopes: list[str]) -> str:
    q = {
        "client_id": _appid(),
        "redirect_uri": _redirect(),
        "state": state,
        "response_type": "code",
        "scope": " ".join(scopes),
    }
    return "https://www.facebook.com/v21.0/dialog/oauth?" + up.urlencode(q)

def exchange_code_for_token(code: str) -> dict:
    r = rq.get(f"{GRAPH}/oauth/access_token", params={
        "client_id": _appid(),
        "client_secret": _secret(),
        "redirect_uri": _redirect(),
        "code": code,
    }, timeout=20)
    r.raise_for_status()
    return r.json()

def exchange_long_lived(short_token: str) -> dict:
    r = rq.get(f"{GRAPH}/oauth/access_token", params={
        "grant_type": "fb_exchange_token",
        "client_id": _appid(),
        "client_secret": _secret(),
        "fb_exchange_token": short_token,
    }, timeout=20)
    r.raise_for_status()
    return r.json()

def me(token: str) -> dict:
    return rq.get(f"{GRAPH}/me",
                  params={"fields": "id,name", "access_token": token},
                  timeout=20).json()

def list_pages(token: str) -> dict:
    fields = "id,name,tasks,instagram_business_account,connected_instagram_account"
    return rq.get(f"{GRAPH}/me/accounts",
                  params={"fields": fields, "access_token": token},
                  timeout=20).json()

def ig_media(ig_user_id: str, token: str, limit=50, after=None) -> dict:
    params = {
        "fields": "id,caption,media_type,media_url,timestamp,permalink,comments_count,like_count",
        "limit": limit, "access_token": token
    }
    if after: params["after"] = after
    return rq.get(f"{GRAPH}/{ig_user_id}/media", params=params, timeout=20).json()

def ig_comments(media_id: str, token: str, limit=100, after=None) -> dict:
    params = {
        "fields": "id,username,text,timestamp",
        "limit": limit, "access_token": token
    }
    if after: params["after"] = after
    return rq.get(f"{GRAPH}/{media_id}/comments", params=params, timeout=20).json()
