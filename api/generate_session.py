# api/generate_session.py

from dotenv import load_dotenv
import os
import json
import base64
from instagrapi import Client

# Завантажуємо кореневий .env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

# Ініціалізуємо клієнт без проксі!
cl = Client()

USERNAME = os.getenv("IG_USERNAME")
PASSWORD = os.getenv("IG_PASSWORD")
if not USERNAME or not PASSWORD:
    raise RuntimeError("IG_USERNAME або IG_PASSWORD не знайдені в ENV")

cl.login(USERNAME, PASSWORD)
out_path = os.path.join(os.path.dirname(__file__), "session.json")
cl.dump_settings(out_path)
print(f"✅ Saved session to {out_path}")
