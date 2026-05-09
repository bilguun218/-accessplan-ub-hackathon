import { Request, Response } from 'express';
import axios from 'axios';
import { ApiError } from '../utils/ApiError';
import { env } from '../config/env';

const GEMINI_URL = (model: string, key: string) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;

const SYSTEM_PROMPT = `You are an assistant that parses a user's spoken/written daily task list (often in Mongolian) into a strict JSON array.

Return ONLY a JSON array (no markdown, no prose). Each element must have exactly these keys:
- "order": integer, 1-based, in the order tasks should be done.
- "title": short task title in the same language as input (e.g. "Банк орох").
- "category": one short English keyword identifying the place type. Examples: "bank", "pharmacy", "hospital", "supermarket", "restaurant", "cafe", "school", "gas_station", "atm", "meeting", "other".
- "locationText": the specific place name if the user named one (e.g. "Тэнгис", "Khan Bank Zaisan branch"). If they only described a generic type, use "search nearby <category>" (e.g. "search nearby bank").
- "timeText": time hint from the user (e.g. "өнөөдөр", "tomorrow morning", "evening", "8pm"). Empty string if none.
- "priority": "high" | "medium" | "low". Default "medium" unless input strongly implies otherwise.
- "needsPlaceSearch": boolean. true when locationText starts with "search nearby" or no specific named place was given; false when a specific named place is mentioned.

Preserve the user's intended order. Output a JSON array only.`;

interface ParsedTask {
  order: number;
  title: string;
  category: string;
  locationText: string;
  timeText: string;
  priority: string;
  needsPlaceSearch: boolean;
}

function extractJsonArray(text: string): unknown {
  const trimmed = text.trim();
  // Strip ```json ... ``` fences if present
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  const candidate = fenced ? fenced[1] : trimmed;
  // Find the first '[' and last ']' for safety
  const start = candidate.indexOf('[');
  const end = candidate.lastIndexOf(']');
  if (start === -1 || end === -1 || end <= start) {
    throw new ApiError(502, 'Gemini did not return JSON.');
  }
  const slice = candidate.slice(start, end + 1);
  try {
    return JSON.parse(slice);
  } catch {
    throw new ApiError(502, 'Failed to parse Gemini JSON output.');
  }
}

function normalizeTask(raw: any, fallbackOrder: number): ParsedTask {
  const title = typeof raw?.title === 'string' ? raw.title.trim() : '';
  const category =
    typeof raw?.category === 'string' ? raw.category.trim().toLowerCase() : '';
  const locationText =
    typeof raw?.locationText === 'string' ? raw.locationText.trim() : '';
  const timeText =
    typeof raw?.timeText === 'string' ? raw.timeText.trim() : '';
  const priorityRaw =
    typeof raw?.priority === 'string' ? raw.priority.trim().toLowerCase() : '';
  const priority = ['high', 'medium', 'low'].includes(priorityRaw)
    ? priorityRaw
    : 'medium';
  const needsPlaceSearch =
    typeof raw?.needsPlaceSearch === 'boolean'
      ? raw.needsPlaceSearch
      : locationText.toLowerCase().startsWith('search nearby');
  const order =
    typeof raw?.order === 'number' && Number.isFinite(raw.order)
      ? Math.trunc(raw.order)
      : fallbackOrder;

  return {
    order,
    title,
    category,
    locationText,
    timeText,
    priority,
    needsPlaceSearch,
  };
}

export async function parseTasks(req: Request, res: Response) {
  const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
  if (!text) {
    throw new ApiError(400, 'text шаардлагатай.');
  }

  if (!env.geminiApiKey) {
    throw new ApiError(500, 'GEMINI_API_KEY тохируулагдаагүй байна.');
  }

  try {
    const response = await axios.post(
      GEMINI_URL(env.geminiModel, env.geminiApiKey),
      {
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ role: 'user', parts: [{ text }] }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
        },
      },
      {
        timeout: 25000,
        headers: { 'Content-Type': 'application/json' },
      },
    );

    const candidates = response.data?.candidates;
    const partText: string | undefined =
      candidates?.[0]?.content?.parts?.[0]?.text;

    if (!partText) {
      throw new ApiError(502, 'Gemini хариу хоосон байна.');
    }

    const parsed = extractJsonArray(partText);
    if (!Array.isArray(parsed)) {
      throw new ApiError(502, 'Gemini did not return a JSON array.');
    }

    const tasks: ParsedTask[] = parsed.map((item, idx) =>
      normalizeTask(item, idx + 1),
    );

    res.json({ tasks });
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if (axios.isAxiosError(err)) {
      const status = err.response?.status ?? 502;
      const upstreamMsg =
        (err.response?.data as any)?.error?.message ?? err.message;
      throw new ApiError(
        status >= 500 ? 502 : status,
        `Gemini API алдаа: ${upstreamMsg}`,
      );
    }
    throw new ApiError(500, 'Дотоод алдаа гарлаа.');
  }
}
