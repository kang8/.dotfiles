#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { text } from 'stream/consumers';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function debug(data) {
  if (process.env.CLAUDE_DEBUG === 0) {
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

async function main() {
  const stdinData = await text(process.stdin);
  const hookData = JSON.parse(stdinData);

  debug(hookData);

  const {
    cwd,
    hook_event_name,
    message,
  } = hookData;

  const projectName = cwd?.split('/').pop() || 'Unknown Project';

  const eventMessages = {
    'Notification':
      message?.replace('Claude needs your permission to use ', '') ||
      'Awaiting your input',
    'Stop': message || 'Done',
  };

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
  });
}

main();
