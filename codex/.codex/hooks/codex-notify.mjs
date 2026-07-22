#!/usr/bin/env node

import { text } from 'stream/consumers';

async function main() {
  const stdinData = await text(process.stdin);
  const hookData = JSON.parse(stdinData);

  const { cwd, last_assistant_message } = hookData;

  const projectName = cwd?.split('/').pop() || 'Unknown Project';
  const body = last_assistant_message
    ? last_assistant_message.slice(0, 200)
    : 'Done';

  await fetch('https://api.day.app/push', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      device_key: process.env.BARK_KEY,
      title: projectName,
      body,
      group: 'Codex',
      icon: 'https://openai.com/favicon.ico',
    }),
  });
}

main();
