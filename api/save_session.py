import os
import json
import base64
from instagrapi import Client
from instagrapi.exceptions import ChallengeRequired, ChallengeUnknownStep, TwoFactorRequired

def prompt(msg):
    return input(msg).strip()

username = os.getenv("IG_USERNAME") or prompt("Instagram username: ")
password = os.getenv("IG_PASSWORD") or prompt("Instagram password: ")

cl = Client()

try:
    cl.login(username, password)
except (ChallengeRequired, ChallengeUnknownStep) as e:
    # Виведемо повністю всі аргументи винятку
    print("\n⚠️ Instagram challenge! Ось contents e.args:\n")
    print(e.args)
    # а також їхній тип
    print("\n⚠️ types of e.args elements:\n")
    for i, arg in enumerate(e.args):
        print(i, type(arg))
    raise SystemExit("\n🚨 Скопіюй цей вивід сюди, щоб я побачив, що в e.args.\n")

except TwoFactorRequired:
    print("⚠️ Потрібен код двофакторної аутентифікації (2FA).")
    code = prompt("Введіть 2FA код: ")
    cl.two_factor_login(code)

# Якщо дійшло сюди — логін пройшов без challenge
settings = cl.get_settings()
b64 = base64.b64encode(json.dumps(settings).encode("utf-8")).decode("utf-8")
print(f"\n\nSESSION_JSON_B64={b64}\n")
