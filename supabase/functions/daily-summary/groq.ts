/**
 * Thin wrapper around Groq's OpenAI-compatible chat completions endpoint.
 * Returns parsed JSON or throws — the caller converts to a structured
 * failure status before writing to the entries table.
 */

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

export interface DiaryOutput {
  body: string;
  top_skill: 'logic' | 'vitality' | 'linguistics' | 'culture' | 'academic';
}

export async function callGroq(opts: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  userPayload: unknown;
  temperature?: number;
}): Promise<{ output: DiaryOutput; rawModel: string }> {
  const body = {
    model: opts.model,
    temperature: opts.temperature ?? 0.7,
    max_tokens: 350,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: opts.systemPrompt },
      { role: 'user', content: JSON.stringify(opts.userPayload) },
    ],
  };

  const res = await fetch(GROQ_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${opts.apiKey}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15_000),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`groq ${res.status}: ${text.slice(0, 200)}`);
  }

  const json = await res.json();
  const content: string | undefined = json?.choices?.[0]?.message?.content;
  if (!content) throw new Error('groq returned no content');

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`groq returned non-JSON: ${content.slice(0, 200)}`);
  }

  const output = validateDiaryOutput(parsed);
  return { output, rawModel: json.model ?? opts.model };
}

function validateDiaryOutput(raw: unknown): DiaryOutput {
  if (!raw || typeof raw !== 'object') throw new Error('output not an object');
  const r = raw as Record<string, unknown>;
  if (typeof r.body !== 'string' || r.body.length === 0) {
    throw new Error('output.body missing or empty');
  }
  const allowed = ['logic', 'vitality', 'linguistics', 'culture', 'academic'];
  if (typeof r.top_skill !== 'string' || !allowed.includes(r.top_skill)) {
    throw new Error(`output.top_skill invalid: ${r.top_skill}`);
  }
  return { body: r.body, top_skill: r.top_skill as DiaryOutput['top_skill'] };
}
