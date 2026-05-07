/**
 * voice-transcribe — runs after the mobile app uploads a voice note to
 * the voice/ bucket and inserts the matching voice_notes row with
 * status='pending'.
 *
 * Two model passes via Groq's OpenAI-compatible API:
 *   1. whisper-large-v3 → transcript in source language (likely de).
 *   2. llama-3.3-70b-versatile → English translation + a small list of
 *      A2-targeted German corrections.
 *
 * Trigger:
 *   - Either invoked directly by the app right after upload, or by a
 *     pg_net trigger on voice_notes insert. The function is idempotent
 *     when called repeatedly: it will re-run only if the row's status
 *     is still 'pending'.
 *
 * Request:
 *   POST { voice_note_id }
 *   Authorization: Bearer <supabase user jwt>
 *
 * Env required:
 *   GROQ_API_KEY — Groq console key, stored in Supabase Vault.
 */

import { createClient } from '@supabase/supabase-js';

interface VoiceNoteRow {
  id: string;
  user_id: string;
  storage_path: string;
  status: string;
}

interface CorrectionItem {
  original: string;
  corrected: string;
  note: string;
}

interface CorrectionsResponse {
  translation_en: string;
  corrections: CorrectionItem[];
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, error: 'method_not_allowed' }, { status: 405 });
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
  const GROQ_KEY = Deno.env.get('GROQ_API_KEY');

  if (!SUPABASE_URL || !SERVICE_ROLE || !ANON_KEY || !GROQ_KEY) {
    return Response.json({ ok: false, error: 'missing_env' }, { status: 500 });
  }

  // Resolve caller from JWT for authorisation; do the actual writes
  // through the service-role client so RLS doesn't block updates from
  // a background Edge Function context.
  const auth = req.headers.get('Authorization');
  if (!auth) {
    return Response.json({ ok: false, error: 'missing_auth' }, { status: 401 });
  }
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return Response.json({ ok: false, error: 'invalid_jwt' }, { status: 401 });
  }
  const callerId = userData.user.id;

  let body: { voice_note_id?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ ok: false, error: 'invalid_json' }, { status: 400 });
  }
  const noteId = body.voice_note_id;
  if (!noteId) {
    return Response.json({ ok: false, error: 'missing_voice_note_id' }, { status: 400 });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  const { data: noteRow, error: readErr } = await admin
    .from('voice_notes')
    .select('id, user_id, storage_path, status')
    .eq('id', noteId)
    .maybeSingle();
  if (readErr) return Response.json({ ok: false, error: readErr.message }, { status: 500 });
  if (!noteRow) return Response.json({ ok: false, error: 'not_found' }, { status: 404 });

  const note = noteRow as VoiceNoteRow;
  if (note.user_id !== callerId) {
    return Response.json({ ok: false, error: 'forbidden' }, { status: 403 });
  }
  if (note.status !== 'pending') {
    // Idempotent: a previous successful run already filled the row.
    return Response.json({ ok: true, skipped: true });
  }

  try {
    const audio = await downloadAudio(admin, note.storage_path);
    const { transcript, language } = await transcribe(GROQ_KEY, audio, note.storage_path);
    const corrections = await translateAndCorrect(GROQ_KEY, transcript, language);

    const { error: updErr } = await admin.from('voice_notes').update({
      language,
      transcript_de: transcript,
      transcript_en: corrections.translation_en,
      corrections: corrections.corrections,
      status: 'ok',
      processed_at: new Date().toISOString(),
      error: null,
    }).eq('id', note.id);
    if (updErr) throw new Error(`update: ${updErr.message}`);

    return Response.json({ ok: true });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await admin.from('voice_notes').update({
      status: 'failed',
      error: msg,
      processed_at: new Date().toISOString(),
    }).eq('id', note.id);
    return Response.json({ ok: false, error: msg }, { status: 500 });
  }
});

async function downloadAudio(
  admin: ReturnType<typeof createClient>,
  storagePath: string,
): Promise<Blob> {
  const { data, error } = await admin.storage.from('voice').download(storagePath);
  if (error || !data) {
    throw new Error(`storage download: ${error?.message ?? 'no body'}`);
  }
  return data;
}

async function transcribe(
  apiKey: string,
  audio: Blob,
  storagePath: string,
): Promise<{ transcript: string; language: string }> {
  const form = new FormData();
  // Groq's Whisper endpoint requires a filename hint to determine codec.
  const filename = storagePath.split('/').pop() ?? 'voice.m4a';
  form.append('file', audio, filename);
  form.append('model', 'whisper-large-v3');
  form.append('response_format', 'verbose_json');
  // No language hint — let Whisper detect (covers German, Turkish, English).
  form.append('temperature', '0');

  const res = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}` },
    body: form,
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) {
    throw new Error(`whisper ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
  const json = await res.json();
  const text = (json.text as string | undefined)?.trim();
  if (!text) throw new Error('whisper returned empty transcript');
  return { transcript: text, language: (json.language as string) ?? 'de' };
}

async function translateAndCorrect(
  apiKey: string,
  transcript: string,
  language: string,
): Promise<CorrectionsResponse> {
  const system = `You are a bilingual German tutor focused on A2 learners.
The user provides a transcript that may be in German, mixed German/English,
or another language entirely. Return strict JSON with two fields:

  translation_en — a clean English translation of the transcript.
  corrections    — an array (possibly empty) of items shaped:
                   { "original": "...", "corrected": "...", "note": "..." }

Rules:
- Only flag corrections when the source is German. For other languages,
  return an empty corrections array.
- Each correction must include the exact erroneous phrase and a one-line
  note explaining why (article, case, conjugation, word order).
- Cap at five corrections; pick the most useful for an A2 learner.
- Do not invent corrections for grammatically valid input.

OUTPUT FORMAT (no markdown fences, strict JSON):
{ "translation_en": "...", "corrections": [ ... ] }`;

  const user = JSON.stringify({ language, transcript });

  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      temperature: 0.2,
      max_tokens: 600,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) {
    throw new Error(`llama ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
  const json = await res.json();
  const content: string | undefined = json?.choices?.[0]?.message?.content;
  if (!content) throw new Error('llama returned no content');

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`llama returned non-JSON: ${content.slice(0, 200)}`);
  }
  return validateCorrections(parsed);
}

function validateCorrections(raw: unknown): CorrectionsResponse {
  if (!raw || typeof raw !== 'object') throw new Error('corrections not an object');
  const r = raw as Record<string, unknown>;
  const translation = typeof r.translation_en === 'string' ? r.translation_en : '';
  const list = Array.isArray(r.corrections) ? r.corrections : [];
  const corrections: CorrectionItem[] = [];
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    const c = item as Record<string, unknown>;
    if (typeof c.original !== 'string' || typeof c.corrected !== 'string') continue;
    corrections.push({
      original: c.original,
      corrected: c.corrected,
      note: typeof c.note === 'string' ? c.note : '',
    });
  }
  return { translation_en: translation, corrections };
}
