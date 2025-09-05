# api/device_emulator.py
import uuid
from typing import Any, Dict, Optional

# опційно: якщо хочеш мати код країни E.164 (не обов'язково для логіну)
try:
    import phonenumbers  # є в requirements
except Exception:
    phonenumbers = None  # type: ignore

DEFAULT_UA = "Instagram 269.0.0.18.75 Android"
DEFAULT_LOCALE = "uk-UA"
IOS_ALIASES = {"ios", "iphone", "ipad", "mac", "macos", "darwin", "ios simulator"}

def _uuid() -> str:
    return str(uuid.uuid4())

def _phone_code(iso: Optional[str], fallback: int = 0) -> int:
    if not iso or not phonenumbers:
        return fallback
    try:
        return phonenumbers.country_code_for_region(iso.upper()) or fallback  # type: ignore[attr-defined]
    except Exception:
        return fallback

def emulate_device(info: Optional[Dict[str, Any]], use_phone_code: bool = True) -> Dict[str, Any]:
    """
    Повертає:
    {
      "settings": {
         "user_agent": str,
         "device_settings": {...},
         "uuids": {...},
         "locale": "uk-UA",
         "timezone_offset": 180,
         "cookies": {},
         "country": "UA",
         "country_code": 380
      },
      "device_agent": str,
      "region": "UA",
      "input_platform": "ios" | "android" | ...
    }
    Без залежності від instagrapi.Client — все генеруємо самі.
    """
    info = dict(info or {})

    # 1) User-Agent: якщо не інстаграмний — підставляємо дефолтний Android UA
    ua_in = str(info.get("userAgent") or "").strip()
    ua = ua_in if ua_in.lower().startswith("instagram") else DEFAULT_UA

    # 2) Платформа: завжди «говоримо» з Instagram як Android,
    #    навіть якщо вхідні дані були iOS/macOS.
    orig_platform = (info.get("platform") or "").lower()
    is_ios_input = orig_platform in IOS_ALIASES
    platform = "Android"

    # якщо прийшов iOS – підставимо стабільний профіль андроїдного девайса
    if is_ios_input:
        info.setdefault("manufacturer", "samsung")
        info.setdefault("model", "SM-G973F")
        info.setdefault("androidVersion", 28)      # Android 9
        info.setdefault("androidRelease", "9")
        info.setdefault("cpu", "qcom")

    # 3) Локаль/час/екран
    locale = info.get("locale") or DEFAULT_LOCALE
    tz = int(info.get("timezoneOffset") or 180)
    screen = info.get("screen") or {}
    w = int(screen.get("width") or 1080)
    h = int(screen.get("height") or 1920)
    pr = float(screen.get("pixelRatio") or 3)

    # 4) Налаштування «андроїдного» девайса, яких очікує instagrapi
    device_settings = {
        "manufacturer":    info.get("manufacturer", "OnePlus"),
        "model":           info.get("model", "6T Dev"),
        "device":          info.get("device", "devitron"),
        "android_version": int(info.get("androidVersion") or 26),
        "android_release": info.get("androidRelease", "8.0.0"),
        "dpi":             f"{int(160 * pr)}dpi",
        "resolution":      f"{w}x{h}",
        "cpu":             info.get("cpu", "qcom"),
        "app_version":     info.get("appVersion", "269.0.0.18.75"),
        "version_code":    info.get("versionCode", "314665256"),
    }

    # 5) UUID-и/ідентифікатори
    uuids = {
        "phone_id":          _uuid(),
        "uuid":              _uuid(),
        "client_session_id": _uuid(),
        "advertising_id":    _uuid(),
        # дві назви для сумісності з різними версіями
        "device_id":         f"android-{uuid.uuid4().hex[:16]}",
        "android_device_id": f"android-{uuid.uuid4().hex[:16]}",
        "request_id":        _uuid(),
        "tray_session_id":   _uuid(),
    }

    # 6) Країна/код країни
    iso = (info.get("country_iso") or "").upper()
    if not iso:
        loc_parts = (info.get("locale") or "").split("-")
        if len(loc_parts) == 2:
            iso = loc_parts[1].upper()
    if not iso:
        iso = "UA"

    country_code = _phone_code(iso, 0) if use_phone_code else 0

    # 7) Об’єкт settings, який очікує main.py/login()
    settings = {
        "user_agent": ua,
        "device_settings": device_settings,
        "uuids": uuids,
        "locale": locale,
        "timezone_offset": tz,
        "cookies": {},           # instagrapi очікує наявність ключа cookies
        "country": iso,
        "country_code": country_code,
    }

    return {
        "settings": settings,
        "device_agent": ua,
        "region": iso,
        "input_platform": orig_platform,  # корисно для дебагу
    }
