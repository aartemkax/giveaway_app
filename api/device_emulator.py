# api/device_emulator.py
import re
import uuid
from typing import Any, Dict, Optional

# опційно: якщо хочеш мати код країни E.164 (не обов'язково для логіну)
try:
    import phonenumbers  # є в requirements
except Exception:
    phonenumbers = None  # type: ignore

DEFAULT_UA = "Instagram 269.0.0.18.75 Android"
DEFAULT_APP_VERSION = "269.0.0.18.75"
DEFAULT_VERSION_CODE = "314665256"
DEFAULT_LOCALE = "uk-UA"
IOS_ALIASES = {"ios", "iphone", "ipad", "mac", "macos", "darwin", "ios simulator"}
INSTAGRAM_APP_VERSION_RE = re.compile(r"^\d+(?:\.\d+){2,}$")

def _uuid() -> str:
    return str(uuid.uuid4())

def _phone_code(iso: Optional[str], fallback: int = 0) -> int:
    if not iso or not phonenumbers:
        return fallback
    try:
        return phonenumbers.country_code_for_region(iso.upper()) or fallback  # type: ignore[attr-defined]
    except Exception:
        return fallback

def _normalize_android_profile(info: Dict[str, Any]) -> Dict[str, Any]:
    normalized = dict(info)
    manufacturer = str(normalized.get("manufacturer") or "").strip()
    model = str(normalized.get("model") or "").strip()
    cpu = str(normalized.get("cpu") or "").strip().lower()

    is_emulator = (
        "sdk_gphone" in model.lower()
        or model.lower().startswith("emulator")
        or cpu in {"ranchu", "goldfish"}
        or str(normalized.get("device") or "").strip().lower() == "devitron"
    )
    if is_emulator:
        normalized.update({
            "manufacturer": "Google",
            "model": "Pixel 7",
            "device": "panther",
            "cpu": "arm64-v8a",
            "androidVersion": 33,
            "androidRelease": "13",
        })
    elif not normalized.get("device"):
        fallback_device = re.sub(r"[^a-z0-9]+", "_", model.lower()).strip("_") or "android"
        normalized["device"] = fallback_device

    app_version = str(normalized.get("appVersion") or "").strip()
    if not INSTAGRAM_APP_VERSION_RE.match(app_version):
        normalized["appVersion"] = DEFAULT_APP_VERSION

    version_code = str(normalized.get("versionCode") or "").strip()
    if not version_code.isdigit():
        normalized["versionCode"] = DEFAULT_VERSION_CODE

    try:
        android_version = int(normalized.get("androidVersion") or 0)
    except (TypeError, ValueError):
        android_version = 0
    if android_version <= 0 or android_version > 34:
        normalized["androidVersion"] = 33
    if not str(normalized.get("androidRelease") or "").strip() or str(normalized.get("androidRelease")) == "16":
        normalized["androidRelease"] = "13"

    if not manufacturer:
        normalized["manufacturer"] = "Google"
    if not model:
        normalized["model"] = "Pixel 7"

    return normalized

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
    info = _normalize_android_profile(dict(info or {}))

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
        "device":          info.get("device", "panther"),
        "android_version": int(info.get("androidVersion") or 26),
        "android_release": info.get("androidRelease", "8.0.0"),
        "dpi":             f"{int(160 * pr)}dpi",
        "resolution":      f"{w}x{h}",
        "cpu":             info.get("cpu", "qcom"),
        "app_version":     info.get("appVersion", DEFAULT_APP_VERSION),
        "version_code":    info.get("versionCode", DEFAULT_VERSION_CODE),
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
