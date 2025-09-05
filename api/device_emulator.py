# api/device_emulator.py
import uuid
from typing import Any, Dict

# опційно: якщо хочеш мати код країни E.164 (не обов'язково для логіну)
try:
    import phonenumbers  # вже є у requirements
except Exception:
    phonenumbers = None

DEFAULT_UA = "Instagram 269.0.0.18.75 Android"
DEFAULT_LOCALE = "uk-UA"

def _uuid() -> str:
    return str(uuid.uuid4())

def _phone_code(iso: str | None, fallback: int = 0) -> int:
    if not iso or not phonenumbers:
        return fallback
    try:
        return phonenumbers.country_code_for_region(iso.upper()) or fallback
    except Exception:
        return fallback

def emulate_device(info: Dict[str, Any] | None, use_phone_code: bool = True) -> Dict[str, Any]:
    """
    Повертає:
    {
      "settings": {
         "user_agent": str,
         "device_settings": {...},
         "uuids": {...},
         "locale": "uk-UA",
         "timezone_offset": 180,
         "cookies": {}
      },
      "device_agent": str,
      "region": "UA"
    }
    Без залежності від instagrapi.Client.
    """
    info = info or {}

    ua       = info.get("userAgent") or DEFAULT_UA
    locale   = info.get("locale") or DEFAULT_LOCALE
    tz       = int(info.get("timezoneOffset") or 180)
    screen   = info.get("screen") or {}
    w        = int(screen.get("width") or 1080)
    h        = int(screen.get("height") or 1920)
    pr       = float(screen.get("pixelRatio") or 3)

    # базові android-параметри, яких чекає instagrapi
    device_settings = {
        "manufacturer":   info.get("manufacturer", "OnePlus"),
        "model":          info.get("model", "6T Dev"),
        "device":         info.get("platform", "devitron"),
        "android_version": int(info.get("androidVersion") or 26),
        "android_release": info.get("androidRelease", "8.0.0"),
        "dpi":             f"{int(160 * pr)}dpi",
        "resolution":      f"{w}x{h}",
        "cpu":             info.get("cpu", "qcom"),
        "app_version":     info.get("appVersion", "269.0.0.18.75"),
        "version_code":    info.get("versionCode", "314665256"),
    }

    uuids = {
        "phone_id":          _uuid(),
        "uuid":              _uuid(),
        "client_session_id": _uuid(),
        "advertising_id":    _uuid(),
        # дві назви на різні версії
        "device_id":         f"android-{uuid.uuid4().hex[:16]}",
        "android_device_id": f"android-{uuid.uuid4().hex[:16]}",
        "request_id":        _uuid(),
        "tray_session_id":   _uuid(),
    }

    iso = (info.get("country_iso") or "").upper()
    if not iso:
        # спробуємо витягнути з locale типу "uk-UA"
        loc = (info.get("locale") or "").split("-")
        if len(loc) == 2:
            iso = loc[1].upper()

    country_code = _phone_code(iso, 0) if use_phone_code else 0

    settings = {
        "user_agent": ua,
        "device_settings": device_settings,
        "uuids": uuids,
        "locale": locale,
        "timezone_offset": tz,
        "cookies": {},          # важливо: instagrapi очікує ключ cookies
        # деякі версії читають ці поля з settings:
        "country": iso or "UA",
        "country_code": country_code,
    }

    return {
        "settings": settings,
        "device_agent": ua,
        "region": iso or "UA",
    }
