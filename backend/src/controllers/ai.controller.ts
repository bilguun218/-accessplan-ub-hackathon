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

If the user writes multiple actions without punctuation, split them into separate tasks too.
Example: "эмийн сан орох банк орох хүнс авах" must become three tasks: pharmacy, bank, supermarket.

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

function splitTaskText(text: string): string[] {
  const normalized = text.replace(/(^|\s)(?:\d+[\.)]|[-•])\s+/g, '\n');
  return normalized
    .split(
      /,|\.|;|\n|&| and | then | also | next | дараа нь | дараа | тэгээд | мөн | бас | ба | болон /i,
    )
    .flatMap(splitActionBoundaries)
    .map((item) => item.trim())
    .filter(Boolean);
}

function splitActionBoundaries(text: string): string[] {
  const startPattern =
    '(?:банк|эмийн\\s+сан|эмнэлэг|хүнс|дэлгүүр|баримт|бичиг|бараа|кофе|кафе|ресторан|хоол|сургууль|khan\\s+bank|golomt\\s+bank|m\\s+bank|монос|монфарм|emart|nomin|номин|gs25|cu\\b|intermed|pharmacy|hospital|school|restaurant|cafe|market|supermarket)';
  const actionPattern =
    '(?:орох|орно|очих|очно|авах|авна|хүргэх|хүргэнэ|өгөх|өгнө|хийх|хийнэ|төлөх|төлнө|уулзах|уулзана)';
  const boundary = new RegExp(`(${actionPattern})\\s+(?=${startPattern})`, 'gi');
  return text
    .replace(boundary, '$1|||')
    .split('|||')
    .map((item) => item.trim())
    .filter(Boolean);
}

function containsAny(text: string, needles: string[]): boolean {
  return needles.some((needle) => text.includes(needle));
}

function inferCategory(lower: string): string {
  if (containsAny(lower, ['эмийн сан', 'эм ', 'pharmacy', 'аптек'])) {
    return 'pharmacy';
  }
  if (containsAny(lower, ['банк', 'bank', 'atm', 'мөнгө'])) {
    return 'bank';
  }
  if (
    containsAny(lower, [
      'хүнс',
      'дэлгүүр',
      'market',
      'mart',
      'supermarket',
      'emart',
      'nomin',
      'gs25',
      'cu',
    ])
  ) {
    return 'supermarket';
  }
  if (containsAny(lower, ['баримт', 'бичиг', 'document'])) {
    return 'meeting';
  }
  if (containsAny(lower, ['хүргэх', 'delivery', 'package', 'бараа'])) {
    return 'delivery';
  }
  if (containsAny(lower, ['эмнэлэг', 'hospital', 'clinic'])) {
    return 'hospital';
  }
  if (containsAny(lower, ['сургууль', 'school', 'university'])) {
    return 'school';
  }
  if (containsAny(lower, ['кофе', 'кафе', 'cafe', 'coffee'])) {
    return 'cafe';
  }
  if (containsAny(lower, ['хоол', 'ресторан', 'restaurant', 'food'])) {
    return 'restaurant';
  }
  return 'other';
}

function knownPlaceFromText(lower: string): string {
  if (lower.includes('khan') || lower.includes('хаан банк')) {
    return 'Khan Bank';
  }
  if (lower.includes('golomt') || lower.includes('голомт')) {
    return 'Golomt Bank';
  }
  if (lower.includes('m bank')) {
    return 'M bank';
  }
  if (lower.includes('монос')) {
    return 'Монос Эмийн сан';
  }
  if (lower.includes('монфарм')) {
    return 'Монфарм эмийн сан';
  }
  if (lower.includes('emart')) {
    return 'Emart - Chinggis';
  }
  if (lower.includes('nomin') || lower.includes('номин')) {
    return 'Nomin Supermarket';
  }
  if (lower.includes('gs25')) {
    return 'GS25';
  }
  if (lower.includes('intermed')) {
    return 'Intermed Hospital';
  }
  if (lower.includes('cafe camino')) {
    return 'Cafe Camino';
  }
  return '';
}

function inferLocationText(lower: string, category: string): string {
  const known = knownPlaceFromText(lower);
  if (known) return known;
  if (category === 'other' || category === 'meeting' || category === 'delivery') {
    return '';
  }
  return `search nearby ${category}`;
}

function inferTimeText(lower: string): string {
  const timeMatch = lower.match(/\b\d{1,2}[:.]\d{2}\b/);
  if (timeMatch) return timeMatch[0].replace('.', ':');
  const hourMatch = lower.match(/\b\d{1,2}\s*цаг/);
  if (hourMatch) return hourMatch[0].trim();
  if (containsAny(lower, ['маргааш', 'tomorrow'])) return 'маргааш';
  if (containsAny(lower, ['өнөөдөр', 'today'])) return 'өнөөдөр';
  return '';
}

function inferPriority(lower: string): string {
  if (containsAny(lower, ['яаралтай', 'urgent', 'өндөр'])) return 'high';
  if (containsAny(lower, ['дараа', 'later', 'бага'])) return 'low';
  return 'medium';
}

function parseTasksLocally(text: string): ParsedTask[] {
  return splitTaskText(text).map((chunk, idx) => {
    const lower = chunk.toLowerCase();
    const category = inferCategory(lower);
    const locationText = inferLocationText(lower, category);
    return normalizeTask(
      {
        order: idx + 1,
        title: chunk.replace(/\s+/g, ' ').trim() || 'Шинэ ажил',
        category,
        locationText,
        timeText: inferTimeText(lower),
        priority: inferPriority(lower),
        needsPlaceSearch:
          !locationText || locationText.toLowerCase().startsWith('search nearby'),
      },
      idx + 1,
    );
  });
}

export async function parseTasks(req: Request, res: Response) {
  const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
  if (!text) {
    throw new ApiError(400, 'text шаардлагатай.');
  }

  if (!env.geminiApiKey) {
    res.json({ tasks: parseTasksLocally(text), source: 'local' });
    return;
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
    const localTasks = parseTasksLocally(text);

    if (tasks.length <= 1 && localTasks.length > 1) {
      res.json({ tasks: localTasks, source: 'local-split' });
      return;
    }

    res.json({ tasks });
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if (axios.isAxiosError(err)) {
      if (env.isDev) {
        res.json({ tasks: parseTasksLocally(text), source: 'local' });
        return;
      }

      const status = err.response?.status ?? 502;
      const upstreamMsg = (err.response?.data as any)?.error?.message ?? err.message;
      throw new ApiError(status >= 500 ? 502 : status, `Gemini API алдаа: ${upstreamMsg}`);
    }
    throw new ApiError(500, 'Дотоод алдаа гарлаа.');
  }
}
