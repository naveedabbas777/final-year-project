# Grok AI Assistant Setup Guide

## Overview
Your Digital Kissan backend is now configured to use **Grok API** (by xAI) instead of Gemini for the AI assistant. Grok is faster, more responsive, and better suited for agricultural guidance.

---

## ✅ Updated Configuration

### Model & Performance
- **Model**: `grok-4.3` (latest, best quality)
- **Max Tokens**: `2048` (higher limits for comprehensive responses)
- **Temperature**: `0.7` (balanced creativity and accuracy)
- **API Endpoint**: `https://api.x.ai/chat/completions`

### Features
- ✅ English & Urdu support
- ✅ Context-aware agricultural advice
- ✅ High rate limits (10M TPM - tokens per minute)
- ✅ Faster response times than Gemini
- ✅ Better for conversational chat

---

## 🔑 Getting Your Grok API Key

### Step 1: Create xAI Console Account
1. Go to **[console.x.ai](https://console.x.ai)**
2. Sign up or log in
3. Navigate to **API Keys** section

### Step 2: Create New API Key
1. Click **"Create API Key"** or **"New Key"**
2. Give it a name: `digital_kissan_backend`
3. Copy the API key (starts with `sk-` or similar)
4. ⚠️ Save it immediately - you won't see it again!

### Step 3: Add to Backend .env

Open `backend/.env` and add:

```env
GROK_API_KEY=sk_YOUR_API_KEY_HERE
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048
```

Example:
```env
# ... other config ...
MAPBOX_ACCESS_TOKEN=pk.xyz...
GROK_API_KEY=sk_abc123xyz456...
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048
CLOUDINARY_CLOUD_NAME=your_cloud
```

---

## 🚀 Testing the Integration

### 1. Verify Backend Configuration
```bash
cd backend

# Check if .env has GROK_API_KEY
echo $env:GROK_API_KEY  # PowerShell

# Or check the file
cat .env | grep GROK
```

### 2. Restart Backend with New Key
```bash
# Kill existing backend (if running)
npm run dev

# Server will output:
# [Server] Starting on http://0.0.0.0:5000
# [Config] Using AI Model: grok-4.3
```

### 3. Test in Flutter App
```bash
# Make sure backend is running on port 5000

# Start the app
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000
# Replace 10.192.10.221 with your PC IP

# Navigate to: Menu → AI Assistant
# Send a message: "What's the best time to plant rice in Pakistan?"
```

### 4. Expected Response
You should get:
- ✅ Fast response (< 3 seconds typically)
- ✅ Comprehensive agricultural guidance
- ✅ Bilingual support (English/Urdu)
- ✅ Detailed, actionable advice

---

## 🧪 Direct API Test (Curl)

If you want to test without the app:

```bash
# 1. Get your Firebase ID token (from app login)
# Or use curl with auth headers

# 2. Test the endpoint
curl -X POST http://localhost:5000/api/assistant/chat \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "کھریف میں کون سی فصل لگائوں؟",
    "language": "ur",
    "history": []
  }'

# Response should look like:
# {
#   "reply": "خریف میں آپ کے علاقے میں یہ فصلیں اگا سکتے ہیں...",
#   "language": "ur"
# }
```

---

## 📊 Grok API Pricing & Limits

| Plan | Rate Limit | Cost |
|------|-----------|------|
| **Free Trial** | 100 requests/day | Free |
| **Free** | 1M tokens/month | Free |
| **Pro** | 10M TPM | $20/month |

### Check Your Usage
- Go to [console.x.ai](https://console.x.ai)
- Click **"Usage"** tab
- View daily/monthly token consumption

---

## 🌐 Language Support

The system now supports:

### English
```
User: "Best practice for wheat planting?"
Assistant: "For wheat planting in Pakistan, follow these steps..."
```

### Urdu
```
گاہک: "گندم کی کاشت کا بہترین طریقہ؟"
مددگار: "پاکستان میں گندم کی کاشت کے لیے یہ اقدامات کریں..."
```

### Mixed/Auto-detect
```
User: "موسم گرما میں tomato کی دیکھ بھال کیسے کریں؟"
Assistant: "Tomato care in summer heat requires..."
```

---

## ❌ Troubleshooting

### Issue: "AI assistant is not configured"
**Solution:**
```bash
# Check if GROK_API_KEY is set
$env:GROK_API_KEY  # PowerShell

# If not set, add it:
$env:GROK_API_KEY = "sk_your_key_here"

# Restart backend
npm run dev
```

### Issue: "Grok API request failed (401)"
**Problem:** Invalid or expired API key
**Solution:**
1. Go to [console.x.ai/api-keys](https://console.x.ai/api-keys)
2. Check if key is still valid
3. Create a new key if needed
4. Update `backend/.env`
5. Restart backend

### Issue: "Grok returned an empty response"
**Problem:** Model overloaded or malformed request
**Solution:**
1. Wait a few seconds and try again
2. Check if message is not too long (max 4000 chars)
3. Verify language parameter is valid (auto, en, ur, both)

### Issue: Response is slow or timeouts
**Problem:** API rate limit or network issue
**Solution:**
```bash
# Restart backend
npm run dev

# Check network connection
curl https://api.x.ai/health

# Increase max tokens gradually
# In backend/.env:
# GROK_MAX_TOKENS=1024  # Start lower, increase if needed
```

---

## 🔧 Advanced Configuration

### Customize System Prompt
Edit `backend/src/routes/assistant.routes.js`:

```javascript
function buildSystemInstruction(mode, latestText) {
  const parts = [
    'You are an expert agricultural advisor...',
    // ... add custom instructions here
  ];
  // ...
}
```

### Change Response Format
Edit `backend/src/routes/assistant.routes.js`:

```javascript
// Current response:
res.json({
  reply,
  language: normalizeMode(language, message),
});

// Add metadata if needed:
res.json({
  reply,
  language: normalizeMode(language, message),
  tokens_used: data?.usage?.total_tokens,
  model: env.grokModel,
  timestamp: new Date().toISOString(),
});
```

### Adjust Temperature (Creativity)
```javascript
// In assistant.routes.js, fetch request:
body: JSON.stringify({
  model: env.grokModel,
  messages,
  temperature: 0.5,  // Lower = more deterministic
  max_tokens: Number(env.grokMaxTokens) || 2048,
}),
```

---

## 📱 Frontend Display

The Flutter app displays responses automatically. To customize:

Edit `lib/screens/assistant_screen.dart`:

```dart
// Message appearance
Text(
  message.content,
  style: TextStyle(
    fontSize: 14,
    color: message.isUser ? Colors.white : Colors.black87,
  ),
)

// Add language indicator
if (response.language == 'ur')
  Text('اردو میں جواب', style: TextStyle(fontSize: 10))
```

---

## 🎯 Best Practices

### 1. Provide Context
```
✅ Good: "I'm in Punjab, can't start watering due to load-shedding. What should I do?"
❌ Bad: "What do I do?"
```

### 2. Ask Specific Questions
```
✅ Good: "Best fertilizer for cotton in July?"
❌ Bad: "Tell me about farming"
```

### 3. Use Your Preferred Language
```
✅ Good: Ask in Urdu if that's your preference
✅ Good: Ask in English if that's more comfortable
```

### 4. Follow-up Questions
```
User: "When to plant rice?"
Assistant: "Plant in April-May for monsoon..."
User: "What about in drought conditions?"
Assistant: (Uses conversation history for context)
```

---

## 📈 Monitoring & Analytics

### Track Usage
```bash
# Backend logs show each API call:
[AssistantService] Chat request received
[Grok API] Request to grok-4.3
[Grok API] Response: 542 tokens used
[AssistantService] Chat response sent
```

### Monitor Rate Limits
```bash
# Check current limits at console.x.ai
# Free tier: 1M tokens/month
# Each query: 100-500 tokens typically
# Therefore: ~2000-10000 queries/month available
```

---

## 🔗 Resources

- **xAI Console**: [console.x.ai](https://console.x.ai)
- **Grok API Docs**: [docs.x.ai](https://docs.x.ai)
- **Model Comparison**: grok-4.3 vs grok-4.1 vs grok-4.20
  - grok-4.3: Latest, fastest, best for chat ✨
  - grok-4.20: Reasoning model, slower but more accurate
  - grok-4.1: Older, less responsive

---

## ✨ Next Steps

1. ✅ Add GROK_API_KEY to `backend/.env`
2. ✅ Restart backend: `npm run dev`
3. ✅ Test in Flutter app
4. ✅ Monitor usage at [console.x.ai](https://console.x.ai)
5. ✅ Share feedback for improvements

---

**Setup Date**: May 11, 2026
**Model**: grok-4.3
**Max Tokens**: 2048
**Languages**: English, Urdu, Mixed
