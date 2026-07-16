from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
import json
import os
import time
import random
import string
import uvicorn

app = FastAPI(title="MIXWARE Key System", version="1.0")

# ===== СТАТИКА =====
app.mount("/static", StaticFiles(directory="static"), name="static")

# ===== КЛЮЧИ =====
KEYS_FILE = "keys.json"
TTL_MS = 24 * 60 * 60 * 1000  # 24 часа

def load_keys() -> dict:
    if os.path.exists(KEYS_FILE):
        with open(KEYS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def save_keys(keys: dict):
    with open(KEYS_FILE, "w", encoding="utf-8") as f:
        json.dump(keys, f, ensure_ascii=False, indent=2)

def clean_expired_keys() -> dict:
    keys = load_keys()
    now = int(time.time() * 1000)
    changed = False
    for k, v in list(keys.items()):
        if v.get("permanent", False):
            continue
        if now - v.get("created", 0) > TTL_MS:
            del keys[k]
            changed = True
    if changed:
        save_keys(keys)
    return keys

def generate_key() -> str:
    parts = []
    for _ in range(3):
        part = ''.join(random.choices(string.ascii_uppercase + string.digits, k=3))
        parts.append(part)
    return f"KAR-{parts[0]}-{parts[1]}-{parts[2]}"

# ===== ГЛАВНАЯ =====
@app.get("/")
async def root():
    return {"status": "MIXWARE Key System", "version": "1.0"}

# ===== СТРАНИЦА С КАПЧЕЙ =====
@app.get("/key", response_class=HTMLResponse)
async def key_page():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>🔑 MIXWARE Key Generator</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: system-ui, -apple-system, sans-serif;
                background: linear-gradient(135deg, #140a23, #2d1452);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            .card {
                background: rgba(35, 20, 55, 0.95);
                border: 2px solid #503078;
                border-radius: 20px;
                padding: 40px;
                max-width: 500px;
                width: 100%;
                text-align: center;
                box-shadow: 0 20px 60px rgba(15, 5, 25, 0.5);
            }
            h1 { 
                color: #dcc8ff; 
                font-size: 2rem; 
                margin-bottom: 8px; 
                text-shadow: 0 0 20px rgba(180, 80, 255, 0.5);
            }
            .sub { 
                color: #c8b4dc; 
                margin-bottom: 24px; 
                font-size: 0.9rem;
            }
            .captcha-box {
                background: rgba(25, 15, 40, 0.8);
                border: 1px solid #503078;
                border-radius: 12px;
                padding: 20px;
                margin-bottom: 20px;
            }
            .captcha-box .question {
                font-size: 2rem;
                font-weight: bold;
                color: #b450ff;
                text-shadow: 0 0 10px rgba(180, 80, 255, 0.3);
            }
            .captcha-box input {
                width: 100px;
                padding: 12px;
                font-size: 1.3rem;
                background: rgba(30, 15, 50, 0.9);
                border: 2px solid #503078;
                border-radius: 8px;
                text-align: center;
                margin-top: 12px;
                color: #dcc8ff;
                transition: 0.2s;
            }
            .captcha-box input:focus { 
                outline: none; 
                border-color: #b450ff; 
                box-shadow: 0 0 15px rgba(180, 80, 255, 0.3);
            }
            .key-display {
                background: rgba(30, 15, 50, 0.9);
                border: 2px solid #b450ff;
                color: #c864ff;
                font-family: 'Courier New', monospace;
                font-size: 1.5rem;
                padding: 16px;
                border-radius: 12px;
                letter-spacing: 3px;
                margin: 16px 0;
                display: none;
                text-shadow: 0 0 10px rgba(180, 80, 255, 0.5);
                box-shadow: 0 0 20px rgba(180, 80, 255, 0.2);
            }
            button {
                background: linear-gradient(135deg, #b450ff, #c864ff);
                color: white;
                border: none;
                padding: 14px 32px;
                border-radius: 12px;
                font-size: 1.1rem;
                font-weight: bold;
                cursor: pointer;
                transition: 0.3s;
                width: 100%;
                text-shadow: 0 1px 2px rgba(0,0,0,0.3);
                box-shadow: 0 4px 15px rgba(180, 80, 255, 0.4);
            }
            button:hover { 
                background: linear-gradient(135deg, #c864ff, #d878ff);
                box-shadow: 0 6px 20px rgba(180, 80, 255, 0.6);
                transform: translateY(-2px);
            }
            button:disabled { 
                opacity: 0.5; 
                cursor: not-allowed;
                transform: none;
            }
            .error { 
                color: #ff6b6b; 
                margin-top: 8px; 
                font-size: 0.9rem;
            }
            .success { 
                color: #00ff88; 
                margin-top: 8px; 
                font-size: 0.9rem;
            }
            .footer {
                margin-top: 20px;
                font-size: 0.75rem;
                color: #8060a0;
            }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>🔑 MIXWARE Key</h1>
            <div class="sub">Реши капчу, чтобы получить ключ (действует 24 часа)</div>
            
            <div class="captcha-box">
                <div class="question" id="captchaQuestion">2 + 3 = ?</div>
                <input type="number" id="captchaInput" placeholder="?">
                <div id="captchaError" class="error"></div>
            </div>
            
            <div id="keyDisplay" class="key-display">KAR-XXX-XXX-XXX</div>
            <button id="generateBtn" onclick="generateKey()">🎣 Получить ключ</button>
            <div id="statusMsg" class="success"></div>
            <div class="footer">🔑 MIXWARE.LOL · kt471 & Lmrbro</div>
        </div>

        <script>
            let currentCaptcha = { a: 0, b: 0, answer: 0 };
            
            function generateCaptcha() {
                const a = Math.floor(Math.random() * 9) + 1;
                const b = Math.floor(Math.random() * 9) + 1;
                const operators = ['+', '-'];
                const op = operators[Math.floor(Math.random() * operators.length)];
                let answer;
                if (op === '+') answer = a + b;
                else answer = a - b;
                if (answer < 0) { return generateCaptcha(); }
                document.getElementById('captchaQuestion').textContent = `${a} ${op} ${b} = ?`;
                currentCaptcha = { a, b, op, answer };
                document.getElementById('captchaInput').value = '';
                document.getElementById('captchaError').textContent = '';
                document.getElementById('statusMsg').textContent = '';
            }
            
            async function generateKey() {
                const input = document.getElementById('captchaInput');
                const userAnswer = parseInt(input.value);
                const error = document.getElementById('captchaError');
                const status = document.getElementById('statusMsg');
                const btn = document.getElementById('generateBtn');
                
                if (isNaN(userAnswer)) {
                    error.textContent = '❌ Введи ответ!';
                    return;
                }
                
                if (userAnswer !== currentCaptcha.answer) {
                    error.textContent = '❌ Неверный ответ! Попробуй снова.';
                    generateCaptcha();
                    return;
                }
                
                btn.disabled = true;
                error.textContent = '';
                status.textContent = '🔄 Генерация ключа...';
                
                try {
                    const res = await fetch('/api/key/generate', { method: 'POST' });
                    const data = await res.json();
                    if (data.status === 'success') {
                        document.getElementById('keyDisplay').style.display = 'block';
                        document.getElementById('keyDisplay').textContent = data.key;
                        status.textContent = '✅ Ключ сгенерирован! Действует 24 часа.';
                        generateCaptcha();
                    } else {
                        status.textContent = '❌ ' + (data.error || 'Ошибка');
                    }
                } catch(e) {
                    status.textContent = '❌ Ошибка сервера';
                }
                btn.disabled = false;
            }
            
            generateCaptcha();
            
            document.getElementById('captchaInput').addEventListener('keypress', function(e) {
                if (e.key === 'Enter') generateKey();
            });
        </script>
    </body>
    </html>
    """

# ===== API ГЕНЕРАЦИИ КЛЮЧА =====
@app.post("/api/key/generate")
async def generate_key_api():
    keys = load_keys()
    key = generate_key()
    keys[key] = {
        "created": int(time.time() * 1000),
        "permanent": False
    }
    save_keys(keys)
    return {"status": "success", "key": key}

# ===== СПИСОК КЛЮЧЕЙ ДЛЯ RFmy.lua (БЕЗ used) =====
@app.get("/key/list")
async def key_list_json():
    """Возвращает JSON со списком ключей (только ключи, без used)"""
    keys = clean_expired_keys()
    # Формат: {"keys": ["KAR-XXX-XXX-XXX", "KAR-YYY-YYY-YYY"]}
    keys_list = list(keys.keys())
    return JSONResponse(content={"keys": keys_list})

# ===== ЗАПУСК =====
if __name__ == "__main__":
    print("🔑 MIXWARE Key System запущен!")
    print(f"📋 Главная: http://0.0.0.0:9781")
    print(f"🔑 Генератор ключей: http://0.0.0.0:9781/key")
    print(f"📋 Список ключей (JSON): http://0.0.0.0:9781/key/list")
    print(f"📁 Статика: /static/RFmy.lua")
    uvicorn.run(app, host="0.0.0.0", port=9781)