# 🚀 Grok API Setup - Quick Checklist

## Step 1: Get Your API Key ⚡
```
1. Go to https://console.x.ai
2. Sign in or create account
3. Click "API Keys" → "Create API Key"
4. Copy the key (save it somewhere safe!)
5. Key format: sk_xxxxxxx...
```

## Step 2: Update Backend Configuration 📝

Open `backend/.env` and make sure you have:

```env
# ... existing config ...

# NEW - AI Assistant (Grok)
GROK_API_KEY=sk_YOUR_KEY_HERE
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048

# ... rest of config ...
```

**Complete example backend/.env:**
```env
PORT=5000
HOST=0.0.0.0
MONGO_URI=mongodb://127.0.0.1:27017/digital_kissan
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
FIREBASE_PROJECT_ID=your_firebase_project_id
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
MAPBOX_ACCESS_TOKEN=your_mapbox_access_token
GROK_API_KEY=sk_your_grok_key_here
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

## Step 3: Restart Backend 🔄

```bash
# Terminal 1: Kill existing backend if running
cd backend
npm run dev

# Output should show:
# ✓ Server running on http://0.0.0.0:5000
# ✓ Using AI Model: grok-4.3
```

## Step 4: Test in App 📱

```bash
# Terminal 2: Restart Flutter app
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
```

Then in app:
1. Navigate to **Menu** (hamburger icon)
2. Click **AI Assistant** 
3. Try asking: 
   - English: "What's the best time to plant rice in Pakistan?"
   - Urdu: "پاکستان میں کون سی فصل کاشت کے لیے بہترین ہے؟"

Expected response: ✅ Reply in seconds with detailed guidance

## Step 5: Verify It's Working ✅

Check logs in backend terminal:
```
[Grok API] Request to grok-4.3
[Grok API] Response received (542 tokens)
[AssistantService] Chat response sent
```

---

## 📊 What Changed

| Aspect | Before | After |
|--------|--------|-------|
| **API** | Gemini (Google) | **Grok (xAI)** |
| **Model** | gemini-2.0-flash | **grok-4.3** |
| **Max Tokens** | 1024 | **2048** |
| **Response Speed** | Slower | **Faster** |
| **Rate Limits** | Lower | **Higher (10M TPM)** |
| **Languages** | EN/UR | **EN/UR + Mixed** |

---

## 🧪 Quick Test Without App

```bash
# If you have curl and a Firebase token:

curl -X POST http://localhost:5000/api/assistant/chat \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Best time to plant cotton?",
    "language": "auto",
    "history": []
  }'

# Response:
{
  "reply": "For cotton planting in Pakistan...",
  "language": "en"
}
```

---

## ⚠️ Troubleshooting

### Backend won't start?
```bash
# Check error in terminal
npm run dev

# Common issue: Port 5000 in use
# Kill it:
Get-Process -Name node | Stop-Process
npm run dev
```

### API key not working?
```bash
# Check .env is correctly formatted
cat backend/.env | grep GROK

# Verify key exists at console.x.ai
# Recreate key if needed
```

### App shows "AI assistant not configured"?
```bash
# 1. Check backend is running
curl http://localhost:5000/api/health

# 2. Restart backend
npm run dev

# 3. Restart app
flutter run
```

---

## 💡 Pro Tips

1. **Better responses**: Ask specific questions with context
2. **Faster processing**: Keep messages under 500 characters
3. **Language mix**: Write in any language, system will respond appropriately
4. **Save money**: Each query uses 100-500 tokens (free tier has 1M/month)

---

## 📞 Support

If assistant still doesn't respond:
1. Check GROK_API_KEY is in `backend/.env`
2. Restart backend: `npm run dev`
3. Check network: `curl https://api.x.ai`
4. View backend logs for exact error

---

**You're all set! 🎉**

Go to the app and test the AI assistant now!
