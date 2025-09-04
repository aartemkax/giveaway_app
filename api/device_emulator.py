# device_emulator.py
import uuid
from instagrapi import Client
import phonenumbers

DEFAULT_APP_VERSION     = "269.0.0.18.75"
DEFAULT_ANDROID_VERSION = 26
DEFAULT_ANDROID_RELEASE = "8.0.0"
DEFAULT_VERSION_CODE    = "3145665256"

def get_phone_code(iso: str) -> int:
    try:
        return phonenumbers.country_code_for_region(iso.upper()) or 0
    except Exception:
        return 0


def emulate_device(info: dict, use_phone_code: bool = True):
    # 1) device settings
    screen = info.get("screen", {})
    device_settings = {
        "app_version":     info.get("appVersion", DEFAULT_APP_VERSION),
        "android_version": info.get("androidVersion", DEFAULT_ANDROID_VERSION),
        "android_release": info.get("androidRelease", DEFAULT_ANDROID_RELEASE),
        "dpi":             f"{int(screen.get('pixelRatio',3)*160)}dpi",
        "resolution":      f"{screen.get('width',1080)}x{screen.get('height',1920)}",
        "manufacturer":    info.get("manufacturer","Generic"),
        "device":          info.get("platform","generic"),
        "model":           info.get("model","DevModel"),
        "cpu":             info.get("cpu","qcom"),
        "version_code":    info.get("versionCode", DEFAULT_VERSION_CODE)
    }

    # 2) instantiate client & set device
    cl = Client()
    cl.set_device(device_settings)

    # capture correct Instagram UA
    settings = cl.get_settings()
    ua = settings.get("user_agent")

    # 3) mutate UUIDs
    uu = settings.get("uuids", {})
    for key in ("phone_id","uuid","request_id"): uu[key] = str(uuid.uuid4())
    settings["uuids"] = uu

    # 4) apply geo, country, locale
    geo = info.get("geo", {})
    if geo:
        cl.last_geo_location = {
            "lat": geo.get("latitude",0),
            "lng": geo.get("longitude",0),
            "horizontal_accuracy": geo.get("accuracy",50.0),
            "heading":0, "speed":0
        }
    iso = (info.get("country_iso") or "").upper()
    if not iso and "-" in info.get("locale",""): iso = info["locale"].split('-')[1].upper()
    settings.update({
        "country": iso,
        "country_code": get_phone_code(iso) if use_phone_code else iso,
        "locale": info.get("locale","en_US"),
        "timezone_offset": info.get("timezoneOffset",0)
    })

    cl.set_settings(settings)
    try:
        cl.set_locale(settings["locale"])
        cl.set_timezone_offset(settings["timezone_offset"])
    except AttributeError:
        pass

    return {
        "settings": settings,
        "device_agent": ua,
        "geo": cl.last_geo_location
    }