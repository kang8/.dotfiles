import type { Register } from 'claude-code';

export const register: Register = (on) => {
  on('command.run', { command: 'branch' }, async ($, e, next) => {
    const oldId = await $.session.id();
    const result = await next(e);
    if ((await $.session.id()) === oldId) return result;

    const copied = await $.ui.copy({ text: oldId });
    const message = copied.isCopied
      ? `Copied original session id: ${oldId}`
      : `Could not copy session id (${copied.reason}): ${oldId}`;
    // The session switch redraws the screen and drops a toast raised right away.
    void $.clock.sleep(1000).then(() => $.ui.toast(message));
    return result;
  }).catch(($, e, next) => next(e));
};
