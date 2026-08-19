## Kang's Tampermonkey Scripts

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Show all contributions by year in GitHub profile](#show-all-contributions-by-year-in-github-profile)
  - [Features](#features)
  - [Possible subsequent improvements](#possible-subsequent-improvements)
- [Re-request review on GitLab merge requests](#re-request-review-on-gitlab-merge-requests)
  - [Features](#features-1)
  - [Self-hosted instances](#self-hosted-instances)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

### Show all contributions by year in GitHub profile

![show-all-contributions-by-year.gif](https://github.com/kang8/.dotfiles/assets/36906329/b52f0413-bec6-40e3-b7f7-fb2c7da8e5a7)

#### Features

- Show ALL contributions by year in GitHub profile
- Styled summary bar with calendar icon, year count badge, and animated chevron
- Respects GitHub's light/dark theme via CSS custom properties

### Re-request review on GitLab merge requests

GitLab hides its own "Re-request review" redo button while a reviewer is still
`UNREVIEWED` — exactly when a nudge is most useful. Its
[`showRequestReviewButton`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/assets/javascripts/sidebar/components/reviewers/uncollapsed_reviewer_list.vue)
bails out on that state, and the REST API has no equivalent endpoint either.

#### Features

- Adds the missing redo button to any reviewer row that lacks one, in the same
  grid cell the native button would occupy
- Reuses GitLab's own `redo` sprite icon, tinted link-blue against the native
  grey so the two stay tellable apart
- Stays hidden until the reviewer row is hovered (or the button is focused),
  keeping the sidebar as quiet as it was
- Turns into a disabled check once the request goes through, so the same
  reviewer cannot be nudged twice — the state is keyed by user, so it survives a
  Vue re-render
- Calls the same
  [`mergeRequestReviewerRereview`](https://docs.gitlab.com/api/graphql/reference/#mutationmergerequestreviewerrereview)
  GraphQL mutation the native button calls
- Anchors on `data-testid` attributes only, and re-injects through a
  `MutationObserver` after every Vue re-render

#### Self-hosted instances

Besides `gitlab.com`, the metadata block carries an `@include` that covers any
host with `gitlab` in it, so `gitlab.example.com` works out of the box:

```js
// @include *://*gitlab*/*
```

`@match` cannot express this — its host part only allows a leading `*.`, no
infix wildcard. A plain `@include` glob can, and unlike a regex `@include` it
does not trip `eslint: userscripts/avoid-regexp-include` in Tampermonkey's
editor.

For a host that does not contain `gitlab` (say `code.example.com`), add a
`@match` line for it, or list it in Tampermonkey under _Settings_ →
_Includes/Excludes_.

To tell whether the script is running at all, check whether reviewer rows carry
a `data-kang8-rerequest` attribute:

```js
document.querySelectorAll('[data-kang8-rerequest]').length;
```
