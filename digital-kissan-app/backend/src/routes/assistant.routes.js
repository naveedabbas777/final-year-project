import { Router } from 'express';

import { env } from '../config/env.js';
import { requireAuth } from '../middlewares/auth.js';
import { asyncHandler } from '../utils/errors.js';

export const assistantRouter = Router();

async function callOpenAI(messages) {
  if (!env.openaiApiKey) return null;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.openaiApiKey}`,
      },
      body: JSON.stringify({
        model: env.openaiModel,
        messages,
        temperature: 0.7,
        max_tokens: Number(env.openaiMaxTokens) || 1024,
      }),
    });

    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      console.error('[OpenAI Error]', response.status, detail);
      return null;
    }

    const data = await response.json();
    return data?.choices?.[0]?.message?.content?.trim() || null;
  } catch (e) {
    console.error('[OpenAI Request Error]', e.message || e);
    return null;
  }
}

function buildGeminiPrompt(messages) {
  return messages
    .map((entry) => {
      const content = String(entry?.content || '').trim();
      if (!content) return null;
      if (entry.role === 'system') return `System: ${content}`;
      if (entry.role === 'assistant' || entry.role === 'model') return `Assistant: ${content}`;
      return `User: ${content}`;
    })
    .filter(Boolean)
    .join('\n\n');
}

async function callGemini(messages) {
  if (!env.geminiApiKey) return null;

  try {
    const promptText = buildGeminiPrompt(messages);
    const url = `https://generativelanguage.googleapis.com/${env.geminiApiVersion}/models/${encodeURIComponent(env.geminiModel)}:generateContent?key=${encodeURIComponent(env.geminiApiKey)}`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [{ text: promptText }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: Number(env.geminiMaxTokens) || 1024,
        },
      }),
    });

    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      console.error('[Gemini API Error]', response.status, detail);
      return null;
    }

    const data = await response.json();
    return (
      data?.candidates?.[0]?.content?.parts?.map((part) => part?.text || '').join('').trim() ||
      data?.candidates?.[0]?.output?.trim() ||
      data?.candidates?.[0]?.content?.[0]?.text?.trim() ||
      null
    );
  } catch (e) {
    console.error('[Gemini Request Error]', e.message || e);
    return null;
  }
}

function clampText(value, maxLength) {
  return String(value || '').trim().slice(0, maxLength);
}

function detectLanguage(text) {
  return /[\u0600-\u06FF]/.test(String(text || '')) ? 'ur' : 'en';
}

function normalizeMode(mode, latestText) {
  const value = String(mode || 'auto').toLowerCase();
  if (value === 'english' || value === 'en') return 'en';
  if (value === 'urdu' || value === 'ur') return 'ur';
  if (value === 'both') return 'both';
  return detectLanguage(latestText);
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) return [];

  return history
    .slice(-10)
    .map((entry) => {
      const role = entry?.role === 'assistant' ? 'model' : 'user';
      const text = clampText(entry?.content ?? entry?.text ?? '', 2000);
      if (!text) return null;
      return { role, parts: [{ text }] };
    })
    .filter(Boolean);
}

function buildSystemInstruction(mode, latestText) {
  const languageMode = normalizeMode(mode, latestText);
  const parts = [
    'You are an expert agricultural advisor and farming assistant for Digital Kissan.',
    'Your expertise covers: crop selection, seasonal planning, soil health, pest management, irrigation techniques, fertilization, harvesting, post-harvest handling, weather-based farming decisions, and market trends.',
    'IMPORTANT: Provide detailed, comprehensive answers with practical guidance. Write full paragraphs with actionable steps.',
    'Include specific seasonal recommendations and crop-specific advice when relevant.',
    'For any farming question, give context, detailed explanation, and step-by-step guidance.',
    'Answer in a professional, educational tone suitable for farmers of all experience levels.',
    'If you are unsure, acknowledge the limitation and provide related helpful information.',
    'For app-related questions, explain clearly with step-by-step instructions.',
  ];

  if (languageMode === 'ur') {
    parts.push('Reply only in Urdu written in natural everyday language.');
  } else if (languageMode === 'both') {
    parts.push('Reply first in English, then repeat the same answer in Urdu.');
  } else {
    parts.push('Reply in the same language as the user. If the user mixes languages, answer in the language that best matches the last question.');
  }

  return parts.join(' ');
}

assistantRouter.post('/chat', requireAuth, asyncHandler(async (req, res) => {
  if (!env.geminiApiKey && !env.openaiApiKey) {
    res.status(503).json({
      message: 'AI assistant is not configured on the backend. Set GEMINI_API_KEY in backend/.env to enable Gemini, or OPENAI_API_KEY for fallback.',
    });
    return;
  }

  const message = clampText(req.body?.message, 4000);
  const language = req.body?.language ?? 'auto';
  const history = req.body?.history ?? [];

  if (!message) {
    res.status(400).json({ message: 'Message is required' });
    return;
  }

  try {
    const systemInstruction = buildSystemInstruction(language, message);
    
    // Build message history in OpenAI format
    const messages = [
      { role: 'system', content: systemInstruction }
    ];

    // Add conversation history
    if (Array.isArray(history)) {
      history.slice(-10).forEach((entry) => {
        if (entry?.content || entry?.text) {
          const text = clampText(entry.content ?? entry.text ?? '', 2000);
          if (text) {
            messages.push({
              role: entry.role === 'assistant' ? 'assistant' : 'user',
              content: text
            });
          }
        }
      });
    }

    // Add current user message
    messages.push({ role: 'user', content: message });

    let reply = null;

    if (env.geminiApiKey) {
      reply = await callGemini(messages);
    }

    if (!reply && env.openaiApiKey) {
      const openaiReply = await callOpenAI(messages);
      if (openaiReply) {
        reply = openaiReply;
      }
    }

    if (!reply) {
      res.status(502).json({ message: 'Gemini did not return a response' });
      return;
    }

    res.json({
      reply,
      language: normalizeMode(language, message),
    });
  } catch (error) {
    console.error('[AssistantError]', error.message);
    res.status(503).json({
      message: 'AI assistant service temporarily unavailable',
      detail: error.message,
    });
  }
}));