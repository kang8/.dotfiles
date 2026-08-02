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

// Notification bodies are plain text: drop the decorations that only make
// sense in a terminal, and cap the length so the push stays glanceable.
function summarize(text, limit = 400) {
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

  return cleaned.length > limit
    ? cleaned.slice(0, limit - 1).trimEnd() + '…'
    : cleaned;
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

  const eventMessages = {
    'Notification':
      message?.replace('Claude needs your permission to use ', '') ||
      'Awaiting your input',
    // Stop carries no `message`; the reply text lives in last_assistant_message.
    'Stop': summarize(last_assistant_message) || 'Done',
  };

  try {
    await fetch('https://api.day.app/push', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify({
        device_key: process.env.BARK_KEY,
        title: projectName,
        body: eventMessages[hook_event_name],
        group: 'Claude Code',
        icon: 'https://wpforms.com/wp-content/uploads/2024/08/claude-logo.png',
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
