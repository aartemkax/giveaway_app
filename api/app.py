# app.py
import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import requests
from device_emulator import emulate_device

app = Flask(__name__, static_folder="static", static_url_path="")
CORS(app)

@app.route('/avatars/<path:filename>')
def serve_avatars(filename):
    return send_from_directory(
        os.path.join(app.static_folder, "avatars"),
        filename
    )

@app.route('/api/collect_device_geo', methods=['POST'])
def collect_device_geo():
    # ваша реалізація…
    payload   = request.get_json() or {}
    client_ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    try:
        r   = requests.get(f"https://ipwho.is/{client_ip}", timeout=2)
        geo = r.json()
    except:
        geo = {}
    return jsonify({ "geo": geo, "ip": client_ip })

@app.route('/api/device_report', methods=['POST'])
def device_report():
    info   = request.get_json().get("deviceInfo", {})
    result = emulate_device(info, use_phone_code=True)
    return jsonify(result)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
