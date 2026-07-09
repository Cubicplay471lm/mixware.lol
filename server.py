from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
from pydantic import BaseModel
from typing import Optional, List, Dict
import json
import os
import time
import random
import string
from datetime import datetime
import uvicorn
import bcrypt

app = FastAPI(title="Karasik Talk Server", version="3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===== СТАТИКА =====
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    return FileResponse("static/index.html")

@app.get("/admin")
async def admin_page():
    return FileResponse("static/admin.html")

# ===== МОДЕЛИ =====
class Passport(BaseModel):
    fullName: str
    role: str = "Обычный карасик"
    birthDate: str = ""

class LoginRequest(BaseModel):
    login: str
    password: str

class RegisterRequest(BaseModel):
    login: str
    password: str
    fullName: str
    role: str = "Обычный карасик"
    birthDate: str = ""

class CreateChatRequest(BaseModel):
    name: str
    member: str
    from_user: str

class SendMessageRequest(BaseModel):
    text: str
    from_user: str

class AddBalanceRequest(BaseModel):
    login: str
    amount: int

class TransferRequest(BaseModel):
    from_user: str
    to: str
    amount: int

class PostRequest(BaseModel):
    text: str
    author: str

class CommentRequest(BaseModel):
    text: str
    author: str

class AnnouncementRequest(BaseModel):
    title: str
    text: str

class AdminLoginRequest(BaseModel):
    password: str

# ===== БАЗА ДАННЫХ =====
class Database:
    def __init__(self, path="karasik_data.json"):
        self.path = path
        self.data = self._load()
    
    def _load(self):
        if os.path.exists(self.path):
            with open(self.path, "r", encoding="utf-8") as f:
                return json.load(f)
        # Создаём базу с хэшем админ-пароля
        admin_hash = bcrypt.hashpw("рыбнадзор".encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        return {
            "users": {},
            "chats": {},
            "posts": {},
            "transactions": {},
            "announcements": {},
            "admin": {
                "password": admin_hash
            }
        }
    
    def _save(self):
        with open(self.path, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)
    
    def get_admin_password(self):
        return self.data.get("admin", {}).get("password", "")
    
    def get_user(self, login: str):
        return self.data["users"].get(login)
    
    def get_all_users(self):
        return self.data["users"]
    
    def create_user(self, login: str, user_data: dict):
        self.data["users"][login] = user_data
        self._save()
    
    def update_user(self, login: str, user_data: dict):
        self.data["users"][login] = user_data
        self._save()
    
    def delete_user(self, login: str):
        if login in self.data["users"]:
            del self.data["users"][login]
            self._save()
    
    def get_chat(self, chat_id: str):
        return self.data["chats"].get(chat_id)
    
    def get_all_chats(self):
        return self.data["chats"]
    
    def create_chat(self, chat_id: str, chat_data: dict):
        self.data["chats"][chat_id] = chat_data
        self._save()
    
    def update_chat(self, chat_id: str, chat_data: dict):
        self.data["chats"][chat_id] = chat_data
        self._save()
    
    def delete_chat(self, chat_id: str):
        if chat_id in self.data["chats"]:
            del self.data["chats"][chat_id]
            self._save()
    
    def get_posts(self):
        return self.data.get("posts", {})
    
    def create_post(self, post_id: str, post_data: dict):
        if "posts" not in self.data:
            self.data["posts"] = {}
        self.data["posts"][post_id] = post_data
        self._save()
    
    def update_post(self, post_id: str, post_data: dict):
        if "posts" in self.data:
            self.data["posts"][post_id] = post_data
            self._save()
    
    def delete_post(self, post_id: str):
        if "posts" in self.data and post_id in self.data["posts"]:
            del self.data["posts"][post_id]
            self._save()
    
    def get_transactions(self):
        return self.data.get("transactions", {})
    
    def create_transaction(self, tx_id: str, tx_data: dict):
        if "transactions" not in self.data:
            self.data["transactions"] = {}
        self.data["transactions"][tx_id] = tx_data
        self._save()
    
    def get_announcements(self):
        return self.data.get("announcements", {})
    
    def create_announcement(self, ann_id: str, ann_data: dict):
        if "announcements" not in self.data:
            self.data["announcements"] = {}
        self.data["announcements"][ann_id] = ann_data
        self._save()
    
    def delete_announcement(self, ann_id: str):
        if "announcements" in self.data and ann_id in self.data["announcements"]:
            del self.data["announcements"][ann_id]
            self._save()
    
    def clear_all(self):
        # Сохраняем админ-пароль
        admin_hash = self.data.get("admin", {}).get("password", "")
        self.data = {
            "users": {},
            "chats": {},
            "posts": {},
            "transactions": {},
            "announcements": {},
            "admin": {"password": admin_hash}
        }
        self._save()

db = Database("karasik_data.json")

# ===== ХЭШИРОВАНИЕ =====
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain: str, hashed: str) -> bool:
    # Если пароль не хэширован (старый формат), сравниваем напрямую
    if not hashed.startswith("$2b$"):
        return plain == hashed
    return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))

# ===== АДМИН ЛОГИН (С ХЭШОМ) =====
@app.post("/api/admin/login")
async def admin_login(data: AdminLoginRequest):
    admin_hash = db.get_admin_password()
    if not admin_hash:
        # Если нет хэша — создаём
        new_hash = hash_password("рыбнадзор")
        db.data["admin"] = {"password": new_hash}
        db._save()
        admin_hash = new_hash
    
    if verify_password(data.password, admin_hash):
        return {"status": "success", "message": "Добро пожаловать, админ!"}
    else:
        raise HTTPException(status_code=401, detail="Неверный пароль")

# ===== API =====
@app.post("/api/register")
async def api_register(data: RegisterRequest):
    if db.get_user(data.login):
        raise HTTPException(status_code=400, detail="Пользователь уже существует")
    user_data = {
        "password": hash_password(data.password),
        "passport": {"fullName": data.fullName, "role": data.role, "birthDate": data.birthDate},
        "createdAt": datetime.now().isoformat(),
        "chats": [],
        "balance": 0,
        "online": False,
        "lastSeen": 0
    }
    db.create_user(data.login, user_data)
    return {"status": "success"}

@app.post("/api/login")
async def api_login(data: LoginRequest):
    user = db.get_user(data.login)
    if not user:
        raise HTTPException(status_code=400, detail="Пользователь не найден")
    if not verify_password(data.password, user["password"]):
        raise HTTPException(status_code=400, detail="Неверный пароль")
    user["online"] = True
    user["lastSeen"] = int(time.time() * 1000)
    db.update_user(data.login, user)
    user_response = {k: v for k, v in user.items() if k != "password"}
    user_response["login"] = data.login
    return {"status": "success", "user": user_response}

@app.get("/api/users")
async def api_get_users():
    users = db.get_all_users()
    for login in users:
        if "password" in users[login]:
            users[login]["password"] = "***"
    return {"users": users}

@app.get("/api/users/{login}")
async def api_get_user(login: str):
    user = db.get_user(login)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    user_response = {k: v for k, v in user.items() if k != "password"}
    user_response["login"] = login
    return {"user": user_response}

@app.delete("/api/users/{login}")
async def api_delete_user(login: str):
    if not db.get_user(login):
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    db.delete_user(login)
    return {"status": "success"}

@app.put("/api/users/{login}/passport")
async def update_passport(login: str, passport: dict):
    user = db.get_user(login)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    user["passport"] = passport
    db.update_user(login, user)
    return {"status": "success"}

@app.post("/api/admin/balance")
async def api_add_balance(data: AddBalanceRequest):
    user = db.get_user(data.login)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    user["balance"] = (user.get("balance") or 0) + data.amount
    db.update_user(data.login, user)
    return {"status": "success", "new_balance": user["balance"]}

@app.post("/api/transfer")
async def api_make_transfer(data: TransferRequest):
    if data.from_user == data.to:
        raise HTTPException(status_code=400, detail="Нельзя перевести самому себе")
    sender = db.get_user(data.from_user)
    if not sender:
        raise HTTPException(status_code=404, detail="Отправитель не найден")
    receiver = db.get_user(data.to)
    if not receiver:
        raise HTTPException(status_code=404, detail="Получатель не найден")
    if (sender.get("balance") or 0) < data.amount:
        raise HTTPException(status_code=400, detail="Недостаточно средств")
    sender["balance"] = (sender.get("balance") or 0) - data.amount
    receiver["balance"] = (receiver.get("balance") or 0) + data.amount
    db.update_user(data.from_user, sender)
    db.update_user(data.to, receiver)
    tx_id = str(int(time.time() * 1000))
    tx_data = {
        "from": data.from_user,
        "to": data.to,
        "amount": data.amount,
        "timestamp": int(time.time() * 1000)
    }
    db.create_transaction(tx_id, tx_data)
    return {"status": "success", "transaction": tx_data}

@app.get("/api/transactions")
async def api_get_transactions():
    return {"transactions": db.get_transactions()}

# ===== ЧАТЫ =====
@app.post("/api/chats")
async def api_create_chat(data: CreateChatRequest):
    if not db.get_user(data.member):
        raise HTTPException(status_code=400, detail="Пользователь не найден")
    chat_id = str(int(time.time() * 1000))
    chat_data = {
        "name": data.name,
        "members": [data.from_user, data.member],
        "createdBy": data.from_user,
        "createdAt": datetime.now().isoformat(),
        "messages": {}
    }
    db.create_chat(chat_id, chat_data)
    for m in chat_data["members"]:
        user = db.get_user(m)
        if user:
            if "chats" not in user:
                user["chats"] = []
            if chat_id not in user["chats"]:
                user["chats"].append(chat_id)
            db.update_user(m, user)
    return {"status": "success", "chatId": chat_id, "chat": chat_data}

@app.get("/api/chats")
async def api_get_chats():
    return {"chats": db.get_all_chats()}

@app.get("/api/chats/{chat_id}")
async def api_get_chat(chat_id: str):
    chat = db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Чат не найден")
    return {"chat": chat}

@app.post("/api/chats/{chat_id}/join")
async def api_join_chat(chat_id: str, login: str):
    chat = db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Чат не найден")
    if login in chat["members"]:
        raise HTTPException(status_code=400, detail="Уже в чате")
    chat["members"].append(login)
    db.update_chat(chat_id, chat)
    user = db.get_user(login)
    if user:
        if "chats" not in user:
            user["chats"] = []
        if chat_id not in user["chats"]:
            user["chats"].append(chat_id)
        db.update_user(login, user)
    return {"status": "success"}

@app.post("/api/chats/{chat_id}/messages")
async def api_send_message(chat_id: str, data: SendMessageRequest):
    chat = db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Чат не найден")
    msg_id = str(int(time.time() * 1000))
    message = {
        "from": data.from_user,
        "text": data.text,
        "timestamp": int(time.time() * 1000)
    }
    if "messages" not in chat:
        chat["messages"] = {}
    chat["messages"][msg_id] = message
    db.update_chat(chat_id, chat)
    return {"status": "success", "messageId": msg_id}

@app.delete("/api/chats/{chat_id}")
async def api_delete_chat(chat_id: str):
    chat = db.get_chat(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Чат не найден")
    db.delete_chat(chat_id)
    return {"status": "success"}

# ===== ПОСТЫ =====
@app.post("/api/posts")
async def api_create_post(data: PostRequest):
    user = db.get_user(data.author)
    if not user or not user.get("passport"):
        raise HTTPException(status_code=403, detail="У вас нет паспорта")
    post_id = str(int(time.time() * 1000))
    post_data = {
        "author": data.author,
        "text": data.text,
        "timestamp": int(time.time() * 1000),
        "likes": 0,
        "likedBy": {},
        "comments": {}
    }
    db.create_post(post_id, post_data)
    return {"status": "success", "postId": post_id}

@app.get("/api/posts")
async def api_get_posts():
    return {"posts": db.get_posts()}

@app.put("/api/posts/{post_id}/like")
async def api_like_post(post_id: str, login: str):
    posts = db.get_posts()
    if post_id not in posts:
        raise HTTPException(status_code=404, detail="Пост не найден")
    post = posts[post_id]
    liked_by = post.get("likedBy", {})
    likes = post.get("likes", 0)
    if login in liked_by:
        del liked_by[login]
        likes -= 1
    else:
        liked_by[login] = True
        likes += 1
    post["likes"] = likes
    post["likedBy"] = liked_by
    db.update_post(post_id, post)
    return {"status": "success", "likes": likes}

@app.post("/api/posts/{post_id}/comments")
async def api_add_comment(post_id: str, data: CommentRequest):
    user = db.get_user(data.author)
    if not user or not user.get("passport"):
        raise HTTPException(status_code=403, detail="У вас нет паспорта")
    posts = db.get_posts()
    if post_id not in posts:
        raise HTTPException(status_code=404, detail="Пост не найден")
    post = posts[post_id]
    if "comments" not in post:
        post["comments"] = {}
    comment_id = str(int(time.time() * 1000))
    post["comments"][comment_id] = {
        "author": data.author,
        "text": data.text,
        "timestamp": int(time.time() * 1000)
    }
    db.update_post(post_id, post)
    return {"status": "success", "commentId": comment_id}

# ===== ОБЪЯВЛЕНИЯ =====
@app.post("/api/announcements")
async def api_create_announcement(data: AnnouncementRequest):
    ann_id = str(int(time.time() * 1000))
    ann_data = {
        "title": data.title,
        "text": data.text,
        "date": datetime.now().strftime("%d.%m.%Y"),
        "active": True
    }
    db.create_announcement(ann_id, ann_data)
    return {"status": "success", "announcementId": ann_id}

@app.get("/api/announcements")
async def api_get_announcements():
    return {"announcements": db.get_announcements()}

@app.delete("/api/announcements/{ann_id}")
async def api_delete_announcement(ann_id: str):
    db.delete_announcement(ann_id)
    return {"status": "success"}

@app.put("/api/announcements/{ann_id}/toggle")
async def api_toggle_announcement(ann_id: str):
    announcements = db.get_announcements()
    if ann_id not in announcements:
        raise HTTPException(status_code=404, detail="Объявление не найдено")
    announcements[ann_id]["active"] = not announcements[ann_id].get("active", True)
    db.create_announcement(ann_id, announcements[ann_id])
    return {"status": "success"}

# ===== АДМИН =====
@app.get("/api/admin/all")
async def api_get_all():
    return {
        "users": db.get_all_users(),
        "chats": db.get_all_chats(),
        "posts": db.get_posts(),
        "transactions": db.get_transactions(),
        "announcements": db.get_announcements()
    }

@app.post("/api/admin/clear")
async def api_clear_all():
    db.clear_all()
    return {"status": "success"}

# ===== СИСТЕМА КЛЮЧЕЙ =====
KEYS_FILE = "keys.json"
TTL_MS = 24 * 60 * 60 * 1000  # 1 день

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

@app.get("/key", response_class=HTMLResponse)
async def key_page():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>� MIXWARE Key Generator</title>
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
                box-shadow: 0 20px 60px rgba(15, 5, 25, 0.5), inset 0 1px 0 rgba(255,255,255,0.1);
            }
            h1 { 
                color: #dc c8 ff; 
                font-size: 2rem; 
                margin-bottom: 8px; 
                text-shadow: 0 0 20px rgba(180, 80, 255, 0.5);
            }
            .sub { 
                color: #c8b4 dc; 
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
                color: #dc c8 ff;
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
            button:active { transform: translateY(0); }
            button:disabled { 
                opacity: 0.5; 
                cursor: not-allowed;
                transform: none;
            }
            .error { 
                color: #ff6b6b; 
                margin-top: 8px; 
                font-size: 0.9rem;
                text-shadow: 0 0 10px rgba(255, 107, 107, 0.3);
            }
            .success { 
                color: #00ff88; 
                margin-top: 8px; 
                font-size: 0.9rem;
                text-shadow: 0 0 10px rgba(0, 255, 136, 0.3);
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
            <h1>� MIXWARE Key</h1>
            <div class="sub">Реши капчу, чтобы получить ключ (действует 1 день)</div>
            
            <div class="captcha-box">
                <div class="question" id="captchaQuestion">2 + 3 = ?</div>
                <input type="number" id="captchaInput" placeholder="?">
                <div id="captchaError" class="error"></div>
            </div>
            
            <div id="keyDisplay" class="key-display">KAR-XXX-XXX-XXX</div>
            <button id="generateBtn" onclick="generateKey()">🎣 Получить ключ</button>
            <div id="statusMsg" class="success"></div>
            <div class="footer">� MIXWARE.LOL · kt471 & Lmrbro</div>
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
                        status.textContent = '✅ Ключ сгенерирован! Действует 1 день.';
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

@app.get("/key/list")
async def key_list_json():
    """Возвращает JSON со списком активных ключей (без HTML)"""
    keys = clean_expired_keys()
    keys_list = []
    for k, v in keys.items():
        keys_list.append({
            "key": k,
            "created": v.get("created"),
            "used": v.get("used", False)
        })
    keys_list.sort(key=lambda x: x["created"], reverse=True)
    return JSONResponse(content={"keys": keys_list})

# ===== API КЛЮЧЕЙ =====
@app.post("/api/key/generate")
async def generate_key_api():
    keys = load_keys()
    key = generate_key()
    keys[key] = {
        "created": int(time.time() * 1000),
        "used": False
    }
    save_keys(keys)
    return {"status": "success", "key": key}

@app.get("/api/key/list")
async def get_keys_api():
    keys = clean_expired_keys()
    keys_list = []
    for k, v in keys.items():
        keys_list.append({
            "key": k,
            "created": v.get("created"),
            "used": v.get("used", False)
        })
    keys_list.sort(key=lambda x: x["created"], reverse=True)
    return {"keys": keys_list}

@app.post("/api/key/use")
async def use_key(key: str):
    keys = load_keys()
    if key not in keys:
        raise HTTPException(status_code=404, detail="Ключ не найден")
    if keys[key].get("used", False):
        raise HTTPException(status_code=400, detail="Ключ уже использован")
    now = int(time.time() * 1000)
    if now - keys[key].get("created", 0) > TTL_MS:
        del keys[key]
        save_keys(keys)
        raise HTTPException(status_code=400, detail="Ключ истёк (более 1 дня)")
    keys[key]["used"] = True
    save_keys(keys)
    return {"status": "success", "message": "Ключ активирован"}

# ===== СИСТЕМА ЗВОНКОВ (WebRTC) =====
class CallManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}  # login -> WebSocket
        self.active_calls: Dict[str, Dict] = {}  # call_id -> {caller, callee, offer, answer}
    
    async def connect(self, login: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[login] = websocket
    
    def disconnect(self, login: str):
        if login in self.active_connections:
            del self.active_connections[login]
    
    async def send_to_user(self, login: str, message: dict):
        if login in self.active_connections:
            await self.active_connections[login].send_json(message)
    
    async def broadcast_call(self, caller: str, callee: str, call_data: dict):
        """Отправить сигнал звонка вызываемому пользователю"""
        if callee in self.active_connections:
            await self.active_connections[callee].send_json({
                "type": "call_request",
                "caller": caller,
                "call_id": call_data.get("call_id"),
                "offer": call_data.get("offer")
            })
    
    async def send_signal(self, from_user: str, to_user: str, signal_type: str, data: dict):
        """Передать WebRTC сигнал (offer/answer/ice) между пользователями"""
        if to_user in self.active_connections:
            await self.active_connections[to_user].send_json({
                "type": signal_type,
                "from": from_user,
                "data": data
            })

call_manager = CallManager()

@app.websocket("/ws/call")
async def websocket_call(websocket: WebSocket, login: str):
    await call_manager.connect(login, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")
            
            if msg_type == "call_request":
                # Инициировать звонок
                callee = data.get("callee")
                call_id = str(int(time.time() * 1000))
                await call_manager.broadcast_call(login, callee, {
                    "call_id": call_id,
                    "offer": data.get("offer")
                })
            
            elif msg_type == "call_answer":
                # Ответ на звонок
                caller = data.get("caller")
                await call_manager.send_signal(login, caller, "call_answer", {
                    "answer": data.get("answer"),
                    "call_id": data.get("call_id")
                })
            
            elif msg_type == "ice_candidate":
                # ICE кандидаты
                target = data.get("target")
                await call_manager.send_signal(login, target, "ice_candidate", {
                    "candidate": data.get("candidate"),
                    "call_id": data.get("call_id")
                })
            
            elif msg_type == "end_call":
                # Завершить звонок
                target = data.get("target")
                await call_manager.send_signal(login, target, "end_call", {
                    "call_id": data.get("call_id")
                })
    
    except WebSocketDisconnect:
        call_manager.disconnect(login)

# ===== ЗАПУСК =====
if __name__ == "__main__":
    print("🐟 Karasik Talk Server запущен!")
    print("📋 Главная: http://localhost:8000")
    print("👑 Админка: http://localhost:8000/admin")
    print("🔑 Генератор ключей: http://localhost:8000/key")
    print("📋 Список ключей (JSON): http://localhost:8000/key/list")
    print("🔑 Пароль админа: рыбнадзор (хэшируется в базе)")
    uvicorn.run(app, host="0.0.0.0", port=9781)