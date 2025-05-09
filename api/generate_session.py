# api/generate_session.py

from dotenv import load_dotenv
import os
import json
import base64
from instagrapi import Client

# Підвантажуємо .env з кореня проекту (або вкажіть свій шлях, якщо .env в іншій папці)
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

# Ініціалізуємо клієнт
cl = Client()
# Залогінюємося
USERNAME = os.getenv("IG_USERNAME")
PASSWORD = os.getenv("IG_PASSWORD")

if not USERNAME or not PASSWORD:
    raise RuntimeError("IG_USERNAME або IG_PASSWORD не знайдені в ENV")

cl.login(USERNAME, PASSWORD)

# Дампимо налаштування в session.json
out_path = os.path.join(os.path.dirname(__file__), "session.json")
cl.dump_settings(out_path)
print(f"✅ Saved session to {out_path}")
