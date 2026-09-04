#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { text } from 'stream/consumers';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function debug(data) {
  if (process.env.CLAUDE_DEBUG === '0') {
    return;
  }

  try {
    fs.appendFileSync(
      path.join(__dirname, 'debug.log'),
      JSON.stringify(data) + '\n',
    );
  } catch (err) {
    // If writing fails, handle silently.
  }
}

// Bark relays through APNs, which rejects payloads over 4 KB. One CJK
// character costs three UTF-8 bytes, so budget in bytes, not characters.
function truncateBytes(text, maxBytes) {
  const buf = Buffer.from(text);
  if (buf.length <= maxBytes) {
    return text;
  }

  // Back off to a character boundary: UTF-8 continuation bytes start with 10.
  let end = maxBytes - 3;
  while (end > 0 && (buf[end] & 0xc0) === 0x80) {
    end--;
  }

  return buf.subarray(0, end).toString().trimEnd() + '…';
}

// Notification bodies are plain text: drop the decorations that only make
// sense in a terminal. The watch truncates what it shows, but the full text
// still reaches the Bark app, so keep as much of it as the payload allows.
function summarize(text, maxBytes = 3000) {
  if (!text) {
    return '';
  }

  const cleaned = text
    .replace(/```[\s\S]*?```/g, '[code]') // fenced blocks -> placeholder
    .replace(/[─━—]{3,}/g, '') // ★ Insight rules
    .replace(/^[ \t]*[-*=_]{3,}[ \t]*$/gm, '') // markdown horizontal rules
    .replace(/^[ \t]*[#>]+[ \t]*/gm, '') // headings / blockquote markers
    .replace(/[*_`]/g, '') // inline emphasis + code ticks
    .replace(/[ \t]+$/gm, '')
    .replace(/\n{2,}/g, '\n')
    .trim();

  return truncateBytes(cleaned, maxBytes);
}

async function main() {
  const stdinData = await text(process.stdin);
  const hookData = JSON.parse(stdinData);

  debug(hookData);

  const {
    cwd,
    hook_event_name,
    message,
    last_assistant_message,
  } = hookData;

  const projectName = cwd?.split('/').pop() || 'Unknown Project';

  // Two classes of push: one blocks on an answer, the other just reports.
  // Only the blocking one is a critical alert, which rings through silent mode
  // and Do Not Disturb. Bark reads `volume` as a string on a 0-10 scale.
  const events = {
    'Notification': {
      body: message?.replace('Claude needs your permission to use ', '') ||
        'Awaiting your input',
      group: 'Claude Code · Action Needed',
      level: 'critical',
      volume: '5',
      sound: 'alarm',
      call: '1',
    },
    // Stop carries no `message`; the reply text lives in last_assistant_message.
    // Archive it so a reply the watch truncates is still readable in the app.
    'Stop': {
      body: summarize(last_assistant_message) || 'Done',
      group: 'Claude Code',
      sound: 'chime',
      isArchive: '1',
    },
  };

  const event = events[hook_event_name];
  if (!event) {
    return;
  }

  try {
    await fetch('https://api.day.app/push', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify({
        device_key: process.env.BARK_KEY,
        title: projectName,
        icon: 'https://wpforms.com/wp-content/uploads/2024/08/claude-logo.png',
        ...event,
      }),
      signal: AbortSignal.timeout(8000),
    });
  } catch (err) {
    // Bark push is best-effort; never let a network failure crash the hook.
    debug({ pushError: String(err) });
  }
}

// Catch-all so an unexpected error never produces an uncaught rejection.
main().catch((err) => debug({ mainError: String(err) }));
