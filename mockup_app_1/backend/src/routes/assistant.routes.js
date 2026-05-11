import { Router } from 'express';

import { env } from '../config/env.js';
import { requireAuth } from '../middlewares/auth.js';
import { asyncHandler } from '../utils/errors.js';

export const assistantRouter = Router();

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
  if (!env.grokApiKey) {
    res.status(503).json({
      message: 'AI assistant is not configured on the backend. Set GROK_API_KEY to enable it.',
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

    const url = 'https://api.x.ai/chat/completions';
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.grokApiKey}`,
      },
      body: JSON.stringify({
        model: env.grokModel,
        messages,
        temperature: 0.7,
        max_tokens: Number(env.grokMaxTokens) || 1024,
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      console.error('[Grok API Error]', response.status, detail);
      res.status(502).json({ 
        message: 'Grok API request failed',
        detail: detail.slice(0, 500),
      });
      return;
    }

    const data = await response.json();
    const reply = data?.choices?.[0]?.message?.content?.trim();

    if (!reply) {
      res.status(502).json({ message: 'Grok returned an empty response' });
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