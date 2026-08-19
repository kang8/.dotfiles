// ==UserScript==
// @name              Re-request review on GitLab merge requests
// @name:zh-CN        在 GitLab MR 页面重新请求 review
// @namespace         https://github.com/kang8
// @version           0.3.0
// @updateURL         https://raw.githubusercontent.com/kang8/.dotfiles/master/tampermonkey-scripts/gitlab-re-request-review.js
// @downloadURL       https://raw.githubusercontent.com/kang8/.dotfiles/master/tampermonkey-scripts/gitlab-re-request-review.js
// @description       Always offer the sidebar's "Re-request review" button, even for reviewers who have not started reviewing yet
// @description:zh-CN 让侧边栏的「Re-request review」按钮常驻，对尚未开始 review 的 reviewer 也能重新发起请求
// @author            kang8
// @match             https://gitlab.com/*
// @include           *://*gitlab*/*
// @grant             none
// @run-at            document-idle
// @license           MIT
// @homepage          https://github.com/kang8/.dotfiles/tree/master/tampermonkey-scripts#re-request-review-on-gitlab-merge-requests
// @icon              https://gitlab.com/assets/favicon.ico
// ==/UserScript==

/**
 * GitLab hides its own re-request button while a reviewer is still
 * `UNREVIEWED`, which is exactly when a nudge is most useful:
 *
 *   showRequestReviewButton(user) {
 *     if (this.canRerequest) {
 *       if (!user.mergeRequestInteraction.approved) {
 *         if (this.isDuoCodeReviewInProgress(user)) return false;
 *         return !['UNREVIEWED'].includes(user.mergeRequestInteraction.reviewState);
 *       }
 *       return true;
 *     }
 *     return false;
 *   }
 *
 * This script fills that gap: it drops a button into any reviewer row that
 * lacks one, in the same grid cell, wired to the same GraphQL mutation the
 * native button calls. Rows where GitLab already renders the button are left
 * untouched — ours is tinted link-blue against the native grey so the two are
 * still tellable apart when they sit side by side in one sidebar.
 *
 * @see https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/assets/javascripts/sidebar/components/reviewers/uncollapsed_reviewer_list.vue
 * @see https://docs.gitlab.com/api/graphql/reference/#mutationmergerequestreviewerrereview
 */
(function () {
  'use strict';

  const MR_PATH_PATTERN = /^\/(.+?)\/-\/merge_requests\/(\d+)(?:[/?#]|$)/;
  const INJECTED_ATTRIBUTE = 'data-kang8-rerequest';

  /**
   * Reviewers already nudged, keyed by global ID. Kept outside the DOM because
   * a Vue re-render throws the buttons away, and a fresh one must not come
   * back clickable.
   *
   * @type {Set<string>}
   */
  const requested = new Set();

  const REREVIEW_MUTATION = `
    mutation Kang8Rereview($fullPath: ID!, $iid: String!, $userId: UserID!) {
      mergeRequestReviewerRereview(
        input: { projectPath: $fullPath, iid: $iid, userId: $userId }
      ) {
        errors
      }
    }
  `;

  injectStyle();
  inject();
  observe();

  /** Re-run {@link inject} after every batch of DOM changes GitLab makes. */
  function observe() {
    let scheduled = false;

    new MutationObserver(() => {
      if (scheduled) {
        return;
      }

      scheduled = true;
      requestAnimationFrame(() => {
        scheduled = false;
        inject();
      });
    }).observe(document.body, { childList: true, subtree: true });
  }

  /**
   * Give every reviewer row a re-request button. Idempotent, so it is safe to
   * call on each mutation batch: rows already handled are skipped, which also
   * keeps the observer from looping on our own insertions.
   */
  function inject() {
    const mr = currentMergeRequest();

    if (!mr) {
      return;
    }

    const rows = document.querySelectorAll(
      '[data-testid="reviewers-block-container"] [data-testid="reviewer"]',
    );

    for (const row of rows) {
      const handled = row.hasAttribute(INJECTED_ATTRIBUTE) ||
        row.querySelector('[data-testid="re-request-button"]');

      if (handled) {
        continue;
      }

      const userId = reviewerId(row);
      const anchor = row.querySelector(
        '[data-testid="reviewer-state-icon-parent"]',
      );

      if (!userId || !anchor) {
        continue;
      }

      row.setAttribute(INJECTED_ATTRIBUTE, '');
      anchor.before(button(mr, userId));
    }
  }

  /**
   * @param {Element} row A `[data-testid="reviewer"]` grid row.
   * @returns {string | null} The reviewer's GraphQL global ID.
   */
  function reviewerId(row) {
    const link = row.querySelector('a[data-user-id]');
    const id = link && link.dataset.userId;

    return id ? `gid://gitlab/User/${id}` : null;
  }

  /**
   * @param {{ fullPath: string, iid: string }} mr
   * @param {string} userId
   * @returns {HTMLButtonElement}
   */
  function button(mr, userId) {
    const element = document.createElement('button');
    element.type = 'button';
    element.className = 'kang8-rrr-button';

    if (requested.has(userId)) {
      markDone(element);

      return element;
    }

    setLook(element, 'redo', 'Re-request review (userscript)');

    element.addEventListener('click', async () => {
      element.disabled = true;

      try {
        const data = await graphql(REREVIEW_MUTATION, { ...mr, userId });
        const errors = data.mergeRequestReviewerRereview.errors;

        if (errors.length > 0) {
          throw new Error(errors.join('; '));
        }

        requested.add(userId);
        markDone(element);
      } catch (error) {
        element.dataset.state = 'failed';
        element.title = `Re-request failed: ${error.message}`;
        element.disabled = false;
      }
    });

    return element;
  }

  /**
   * Settle the button into its terminal state: a check that cannot be clicked
   * again, so the same reviewer never gets nudged twice.
   *
   * @param {HTMLButtonElement} element
   */
  function markDone(element) {
    element.dataset.state = 'done';
    element.disabled = true;
    setLook(element, 'check', 'Review re-requested');
  }

  /**
   * @param {HTMLButtonElement} element
   * @param {'redo' | 'check'} iconName
   * @param {string} label
   */
  function setLook(element, iconName, label) {
    element.title = label;
    element.setAttribute('aria-label', label);
    element.replaceChildren(icon(iconName));
  }

  /**
   * Reuse GitLab's own sprite so the icon matches the surrounding controls
   * pixel for pixel, falling back to a glyph on instances that do not expose
   * the sprite path.
   *
   * @param {'redo' | 'check'} name
   * @returns {Element}
   */
  function icon(name) {
    const sprite = window.gon && window.gon.sprite_icons;

    if (!sprite) {
      const glyph = document.createElement('span');
      glyph.textContent = name === 'check' ? '✓' : '↻';

      return glyph;
    }

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', '16');
    svg.setAttribute('height', '16');
    svg.setAttribute('aria-hidden', 'true');

    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', `${sprite}#${name}`);
    svg.append(use);

    return svg;
  }

  /**
   * @returns {{ fullPath: string, iid: string } | null}
   */
  function currentMergeRequest() {
    const relativeRoot = (window.gon && window.gon.relative_url_root) || '';
    const path = location.pathname.startsWith(relativeRoot)
      ? location.pathname.slice(relativeRoot.length)
      : location.pathname;
    const match = MR_PATH_PATTERN.exec(path);

    return match ? { fullPath: match[1], iid: match[2] } : null;
  }

  /**
   * @param {string} query
   * @param {object} variables
   * @returns {Promise<object>} The `data` payload.
   */
  async function graphql(query, variables) {
    const relativeRoot = (window.gon && window.gon.relative_url_root) || '';
    const meta = document.querySelector('meta[name="csrf-token"]');
    const csrfToken = (meta && meta.content) ||
      (window.gon && window.gon.csrf_token) || '';

    const response = await fetch(`${relativeRoot}/api/graphql`, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
      },
      body: JSON.stringify({ query, variables }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const payload = await response.json();

    if (payload.errors) {
      throw new Error(payload.errors.map((error) => error.message).join('; '));
    }

    return payload.data;
  }

  function injectStyle() {
    const style = document.createElement('style');

    style.textContent = `
      .kang8-rrr-button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 20px;
        height: 20px;
        margin-right: 8px;
        padding: 0;
        border: 0;
        background: transparent;
        color: var(--gl-text-color-link, #1f75cb);
        line-height: 1;
        cursor: pointer;
        opacity: 0;
        pointer-events: none;
        transition: opacity 0.1s ease;
      }

      /*
       * Reveal on row hover only. Hiding with opacity rather than display
       * keeps the grid cell reserved, so nothing shifts as the pointer moves
       * down the reviewer list.
       */
      [data-testid='reviewer']:hover .kang8-rrr-button,
      .kang8-rrr-button:focus-visible,
      .kang8-rrr-button[data-state='done'],
      .kang8-rrr-button[data-state='failed'] {
        opacity: 1;
        pointer-events: auto;
      }

      .kang8-rrr-button:hover:not(:disabled) {
        color: var(--gl-text-color-link-hover, #0b5cad);
      }

      .kang8-rrr-button:disabled {
        cursor: default;
      }

      .kang8-rrr-button[data-state='done'] {
        color: var(--gl-text-color-success, #217645);
      }

      .kang8-rrr-button[data-state='failed'] {
        color: var(--gl-text-color-danger, #dd2b0e);
      }
    `;

    document.head.append(style);
  }
})();
