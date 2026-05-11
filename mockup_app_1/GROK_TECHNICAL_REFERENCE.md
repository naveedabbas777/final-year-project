# Grok API Integration - Technical Reference

## 📡 API Endpoint

```
Method: POST
URL: https://api.x.ai/chat/completions
Authentication: Bearer token (GROK_API_KEY from environment)
```

---

## 📤 Request Format

### From Flutter App → Backend

```json
{
  "message": "Best cotton fertilizer schedule?",
  "language": "auto",
  "history": [
    {
      "role": "user",
      "content": "I'm growing cotton in Punjab"
    },
    {
      "role": "assistant",
      "content": "Cotton is a great crop for Punjab..."
    }
  ]
}
```

### Language Options

| Value | Behavior |
|-------|----------|
| `"auto"` | Detects from message content |
| `"en"` | Forces English response |
| `"ur"` | Forces Urdu response |
| `"both"` | Returns English then Urdu |

---

## 🔄 Backend Processing Flow

```
1. Client sends message to /api/assistant/chat with auth token
2. Backend validates authentication with Firebase
3. Backend builds system prompt with language mode
4. Backend adds conversation history (last 10 messages)
5. Backend sends to Grok API:
   {
     "model": "grok-4.3",
     "messages": [
       {"role": "system", "content": "You are an expert agricultural advisor..."},
       {"role": "user", "content": "Best cotton varieties?"},
       {"role": "assistant", "content": "For cotton in Punjab..."},
       {"role": "user", "content": "Current message"}
     ],
     "temperature": 0.7,
     "max_tokens": 2048
   }
6. Grok API returns response
7. Backend extracts text from response
8. Backend returns to client
```

---

## 📥 Response Format

### From Backend → Flutter App

```json
{
  "reply": "For cotton in Punjab, the best fertilizer schedule is:\n\n1. **Initial fertilization**: Apply 100kg nitrogen...",
  "language": "en"
}
```

### Grok API Response (Raw)

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1715425200,
  "model": "grok-4.3",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "For cotton in Punjab, the best fertilizer schedule is..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 342,
    "completion_tokens": 456,
    "total_tokens": 798
  }
}
```

---

## 🛠️ System Prompt Template

The backend builds a dynamic system prompt:

```
You are an expert agricultural advisor and farming assistant for Digital Kissan.

Your expertise covers: crop selection, seasonal planning, soil health, pest management, 
irrigation techniques, fertilization, harvesting, post-harvest handling, weather-based 
farming decisions, and market trends.

IMPORTANT: Provide detailed, comprehensive answers with practical guidance. Write full 
paragraphs with actionable steps.

Include specific seasonal recommendations and crop-specific advice when relevant.

For any farming question, give context, detailed explanation, and step-by-step guidance.

Answer in a professional, educational tone suitable for farmers of all experience levels.

If you are unsure, acknowledge the limitation and provide related helpful information.

For app-related questions, explain clearly with step-by-step instructions.

[LANGUAGE MODE]:
- "en": Reply in the same language as the user. If the user mixes languages, answer 
        in the language that best matches the last question.
- "ur": Reply only in Urdu written in natural everyday language.
- "both": Reply first in English, then repeat the same answer in Urdu.
```

---

## 🔐 Authentication

### Token Flow

```
1. User logs in via Firebase in Flutter app
2. Firebase returns ID token
3. Flutter stores token locally
4. For each assistant request:
   - Flutter sends: Authorization: Bearer <firebase_id_token>
   - Backend verifies token with Firebase Admin SDK
   - Backend checks if user exists in MongoDB
   - If valid, proceeds with request
5. Grok API called independently with GROK_API_KEY (server-side secret)
```

### Security Notes

- ✅ Firebase tokens never exposed to Grok API
- ✅ GROK_API_KEY never sent to client
- ✅ All communication encrypted (HTTPS)
- ✅ User identification via Firebase UID

---

## ⚙️ Configuration Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Model** | grok-4.3 | Latest model, best performance |
| **Max Tokens** | 2048 | Max output length in tokens |
| **Temperature** | 0.7 | Balance between creativity (1.0) and accuracy (0.0) |
| **Endpoint** | https://api.x.ai/chat/completions | Official xAI endpoint |
| **Timeout** | 30 seconds | If no response, request fails |
| **Rate Limit** | 10M TPM (free: 1M/month) | Tokens per minute |

---

## 📊 Token Estimation

Typical token usage per request:

```
System prompt: ~200 tokens
Message history (10 messages): ~300-500 tokens
Current user message: ~50-100 tokens
Response: ~300-500 tokens
─────────────────────────────
Total per query: 850-1300 tokens

Free tier: 1M tokens/month ÷ 1000 tokens/query = ~1000 queries/month
```

---

## 🧪 Curl Test Example

```bash
# Get your Firebase ID token first (from app login)
TOKEN="YOUR_FIREBASE_ID_TOKEN"

# Make request
curl -X POST http://localhost:5000/api/assistant/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Best time to plant rice in Punjab?",
    "language": "auto",
    "history": []
  }' | jq .

# Expected output:
# {
#   "reply": "The best time to plant rice in Punjab is typically...",
#   "language": "en"
# }
```

---

## 🔄 Conversation History

### How It Works

```javascript
// Backend maintains last 10 messages
const history = [
  { role: "user", content: "Growing cotton in Punjab?" },
  { role: "assistant", content: "Cotton grows well in Punjab..." },
  { role: "user", content: "What about pests?" },
  { role: "assistant", content: "Common cotton pests include..." },
  // ... more messages
];

// Each message converted to OpenAI format:
{
  "role": "user" or "assistant",
  "content": "message text"
}

// Sent to Grok with system prompt
```

### Benefits

- ✅ Better context understanding
- ✅ More coherent responses
- ✅ Remembers previous questions
- ✅ Tracks conversation thread

---

## ⚡ Performance Metrics

### Expected Response Times

```
Component           | Time
────────────────────┼──────────
Request processing  | <100ms
Grok API call       | 1-3 sec (typical)
Response parsing    | <50ms
─────────────────────┼──────────
Total               | 1-3 seconds
```

### Optimization Tips

1. **Keep messages short** (<500 chars) = Faster processing
2. **Limit history** (system uses last 10) = Less data to process
3. **Use specific topics** = Better response accuracy
4. **Test in non-peak hours** = Faster Grok response time

---

## 🛡️ Error Handling

### Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad request | Check message is not empty |
| 401 | Unauthorized | Verify Firebase token is valid |
| 403 | Forbidden | User not authorized for this endpoint |
| 502 | Gateway error | Grok API temporarily down |
| 503 | Service unavailable | Backend can't reach Grok or no API key |

### Error Response Format

```json
{
  "message": "Descriptive error message",
  "detail": "Additional technical details"
}
```

---

## 🔄 Full Request/Response Cycle Example

### Request (Flutter → Backend)

```json
POST /api/assistant/chat
Authorization: Bearer eyJhbGciOiJSUzI1NiI...
Content-Type: application/json

{
  "message": "Cotton میں کیڑوں سے بچاؤ؟",
  "language": "ur",
  "history": []
}
```

### Backend Processing

```javascript
1. Verify token: ✅ Valid Firebase token for user_123
2. Build system prompt: "You are an agricultural advisor..."
3. Add language instruction: "Reply only in Urdu..."
4. Build messages array:
   [
     { role: "system", content: "You are an expert..." },
     { role: "user", content: "Cotton میں کیڑوں سے بچاؤ؟" }
   ]
5. Call Grok API with 2048 token limit
6. Wait for response (typically 1-2 seconds)
7. Extract text from response
8. Return to client
```

### Response (Backend → Flutter)

```json
HTTP 200 OK
Content-Type: application/json

{
  "reply": "کپاس میں کیڑوں سے بچاؤ کے طریقے:\n\n1. **بروڈ ڈیمپنگ**: پہی فصل...",
  "language": "ur"
}
```

### Flutter Displays

```
┌─────────────────────────────────────┐
│ AI Assistant                        │
├─────────────────────────────────────┤
│                                     │
│ کپاس میں کیڑوں سے بچاؤ کے طریقے: │
│                                     │
│ 1. بروڈ ڈیمپنگ: پہی فصل...        │
│ 2. زرعی طریقے: پتے کو...         │
│ 3. کیمیائی دوائیں: Imidacloprid... │
│                                     │
└─────────────────────────────────────┘
```

---

## 📈 Scaling Considerations

### If Usage Increases

```
Current: 1M tokens/month (free tier)

If you reach 80%+ usage:
1. Monitor at console.x.ai
2. Consider Pro tier ($20/month for 10M TPM)
3. Or optimize prompts to use fewer tokens

Migration to Pro:
1. Go to console.x.ai
2. Click "Billing" → "Upgrade"
3. Add payment method
4. Unlimited API key is still valid
```

---

## 🔗 Dependencies

### Required

- `backend/src/config/env.js` - Environment configuration
- `GROK_API_KEY` - API key from console.x.ai
- `GROK_MODEL` - Model name (grok-4.3)
- `GROK_MAX_TOKENS` - Max output tokens (2048)

### External Services

- Firebase Admin SDK - Token verification
- xAI Grok API - AI model
- Node.js http/fetch - API communication

### Environment

```env
# backend/.env
GROK_API_KEY=sk_...
GROK_MODEL=grok-4.3
GROK_MAX_TOKENS=2048
```

---

## 🎓 Learning Resources

| Topic | Resource |
|-------|----------|
| Grok API Docs | https://docs.x.ai |
| OpenAI Format | https://platform.openai.com/docs |
| Firebase Auth | https://firebase.google.com/docs/auth |
| Token Counting | https://tiktokenizer.vercel.app |

---

**Technical Reference Document**
**Date:** May 11, 2026
**Model:** grok-4.3
**Status:** Production Ready
