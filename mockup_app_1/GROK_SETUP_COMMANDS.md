# Grok AI Setup - Exact Commands to Run

## 🎯 3-Minute Setup

### Step 1: Get API Key (1 minute)

```powershell
# Open browser and go to:
# https://console.x.ai

# Steps:
# 1. Sign in (or create account)
# 2. Click "API Keys" 
# 3. Click "Create API Key"
# 4. Name it: "digital_kissan_backend"
# 5. Copy the key (looks like: sk_abc123xyz...)
# 6. Save it in a notepad
```

### Step 2: Update Backend Config (1 minute)

```powershell
# Open PowerShell in project folder
cd C:\Users\Naveed\Documents\GitHub\final-year-project\mockup_app_1\backend

# Open .env file with notepad
notepad .env

# Add these lines (replace YOUR_KEY with actual key from step 1):
GROK_API_KEY=sk_YOUR_KEY_HERE
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048

# Save and close notepad (Ctrl+S)
```

**Example .env file content:**
```env
PORT=5000
HOST=0.0.0.0
MONGO_URI=mongodb://127.0.0.1:27017/digital_kissan
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
FIREBASE_PROJECT_ID=your_firebase_project_id
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
MAPBOX_ACCESS_TOKEN=your_mapbox_access_token
GROK_API_KEY=sk_xai1234567890abcdefg
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

### Step 3: Restart Backend (1 minute)

```powershell
# Terminal 1 - Kill old backend if running
Get-Process -Name node | Stop-Process

# Terminal 1 - Start backend
cd C:\Users\Naveed\Documents\GitHub\final-year-project\mockup_app_1\backend
npm run dev

# Wait for output like:
# ✓ Server running on http://0.0.0.0:5000
# ✓ Backend ready
```

### Step 4: Test in App

```powershell
# Terminal 2 - Make sure device is connected
adb devices

# Terminal 2 - Run app
cd C:\Users\Naveed\Documents\GitHub\final-year-project\mockup_app_1
flutter run --dart-define=API_BASE_URL=http://10.192.10.221:5000

# Replace 10.192.10.221 with your PC IP if different
```

Then in the app:
1. Click **Menu** (☰ icon bottom-left)
2. Click **AI Assistant**
3. Type: "What's the best time to plant rice?"
4. You should get a response in 1-3 seconds ✅

---

## 🔍 Verify It's Working

### Check 1: Backend is using Grok

```powershell
# In backend terminal, you should see when you send a message:
[Grok API] Request to grok-4.3
[Grok API] Response received (542 tokens)
```

### Check 2: Direct API Test

```powershell
# If you have your Firebase token, test directly:

$token = "YOUR_FIREBASE_ID_TOKEN"

$body = @{
    message = "Best cotton variety for Punjab"
    language = "auto"
    history = @()
} | ConvertTo-Json

curl -X POST "http://localhost:5000/api/assistant/chat" `
  -Headers @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
  } `
  -Body $body

# Should return:
# {
#   "reply": "For cotton in Punjab, I recommend...",
#   "language": "en"
# }
```

### Check 3: Monitor at Console

```powershell
# Go to https://console.x.ai
# Click "Usage" tab
# You should see requests being logged in real-time
```

---

## 🧪 Test Messages to Try

### English Tests
```
"Best rice varieties for monsoon season in Pakistan?"
→ Should get detailed agricultural guidance

"How to manage cotton pests naturally?"
→ Should get eco-friendly solutions

"Irrigation schedule for wheat in Punjab?"
→ Should get region-specific advice
```

### Urdu Tests
```
"پاکستان میں دال کی کاشت کا صحیح وقت؟"
→ Should get detailed Urdu response

"موسم گرما میں سبزی کی دیکھ بھال کیسے کریں؟"
→ Should get practical summer gardening tips

"مٹی کی تیاری میں کیا احتیاطیں کریں؟"
→ Should get soil preparation guidance
```

### Mixed Language
```
"Summer میں کون سی سبزی grow کر سکتے ہیں؟"
→ System auto-detects mixed language
→ Provides answer in same language pattern
```

---

## ⚠️ Troubleshooting - Quick Fixes

### Error: "AI assistant not configured"

```powershell
# Fix: Check GROK_API_KEY is set

# 1. Open backend/.env
notepad C:\Users\Naveed\Documents\GitHub\final-year-project\mockup_app_1\backend\.env

# 2. Verify these lines exist:
GROK_API_KEY=sk_... (should have actual key)
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048

# 3. If missing or wrong, add/fix them and save

# 4. Restart backend:
Get-Process -Name node | Stop-Process
npm run dev
```

### Error: "Grok API request failed (401)"

```powershell
# Fix: API key is invalid or expired

# 1. Go to https://console.x.ai
# 2. Check if your key still exists
# 3. If not, create a new one
# 4. Update backend/.env with new key
# 5. Restart backend
```

### Error: "Service temporarily unavailable"

```powershell
# Fix: Backend connection or network issue

# 1. Check backend is running:
curl http://localhost:5000/api/health
# Should return: {"status":"ok"}

# 2. If not running, start it:
cd backend
npm run dev

# 3. Check internet connection:
curl https://api.x.ai

# 4. Wait a few seconds and retry
```

### App shows old responses or slow loading

```powershell
# Fix: Clear cache and restart

# 1. Kill backend
Get-Process -Name node | Stop-Process

# 2. Kill flutter
Get-Process -Name flutter | Stop-Process

# 3. Restart backend
cd backend
npm run dev

# 4. Restart app
flutter clean
flutter run
```

---

## 📊 Performance Expectations

After setup, here's what you should see:

```
User: "پاکستان میں گندم کی کاشت؟"
         ↓ (submitted)
    Backend receives: 1-2 sec
    Grok API processes: 1-2 sec
    Backend returns: <1 sec
         ↓
App shows: "دسمبر سے جنوری تک گندم کی کاشت کریں..."
    Total time: 2-5 seconds ✅
```

---

## 🎯 What to Do Next

### Immediate (Do Now)
- [ ] Get GROK_API_KEY from console.x.ai
- [ ] Add to backend/.env
- [ ] Restart backend
- [ ] Test in app

### Short Term (Next Hours)
- [ ] Test both English and Urdu queries
- [ ] Check response quality
- [ ] Monitor usage at console.x.ai
- [ ] Adjust GROK_MAX_TOKENS if needed (default: 2048)

### Long Term (This Week)
- [ ] Monitor token usage trends
- [ ] Consider upgrade to Pro tier if free tier insufficient
- [ ] Customize system prompt for better agricultural guidance
- [ ] Share with other farmers for feedback

---

## 💡 Tips for Best Results

### For Farmers Using the App

**Ask specific questions:**
```
❌ Bad: "Tell me about farming"
✅ Good: "I'm in Punjab, growing cotton. What's the fertilizer schedule?"
```

**Use your language:**
```
✅ English: Type in English if comfortable
✅ Urdu: Type in Urdu for native language response
✅ Mixed: App auto-detects and responds appropriately
```

**Provide context:**
```
❌ Bad: "When to harvest?"
✅ Good: "I planted wheat in December, when should I harvest it?"
```

### For Developers/Admins

**Monitor performance:**
```bash
# Check backend logs every few hours
npm run dev  # Logs show each API call with tokens used

# Monitor at console.x.ai
# Usage tab shows daily/monthly consumption
```

**Optimize if needed:**
```bash
# If responses are too long:
# In backend/.env, reduce:
GROK_MAX_TOKENS=1024

# If responses are too short:
# Increase:
GROK_MAX_TOKENS=4096  # Max is usually 4096

# If responses are too creative:
# In assistant.routes.js, reduce temperature:
temperature: 0.5  # More deterministic
```

---

## 📞 Support Resources

| Need | Where |
|------|-------|
| API Key Issues | https://console.x.ai |
| xAI Docs | https://docs.x.ai |
| Status Page | https://status.x.ai |
| Account Help | https://support.x.ai |

---

## ✅ Success Criteria

You'll know it's working when:

1. ✅ Backend shows `[Grok API] Request to grok-4.3` in logs
2. ✅ App receives reply in 1-3 seconds
3. ✅ Response is in English or Urdu as requested
4. ✅ Response includes practical agricultural guidance
5. ✅ console.x.ai shows token usage in Usage tab

---

## 🚀 Ready to Go!

You're all set! Follow the 3-minute setup above and you'll have a fast, responsive AI assistant for your farmers.

**Questions?** Check `GROK_AI_SETUP.md` for detailed troubleshooting.

---

**Setup Date:** May 11, 2026
**Status:** Ready for Implementation
**Estimated Time:** 3 minutes
**Difficulty:** Easy ⭐
