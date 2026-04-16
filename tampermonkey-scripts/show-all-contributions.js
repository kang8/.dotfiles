// ==UserScript==
// @name              Show all contributions by year in the GitHub profile
// @name:zh-CN        在 GitHub profile 页面以年份展示用户所有的贡献
// @namespace         https://github.com/kang8
// @version           0.0.6
// @updateURL         https://raw.githubusercontent.com/kang8/.dotfiles/master/tampermonkey-scripts/show-all-contributions.js
// @downloadURL       https://raw.githubusercontent.com/kang8/.dotfiles/master/tampermonkey-scripts/show-all-contributions.js
// @description       Show all contributions by year since the user was created in the GitHub profile page
// @description:zh-CN 在 GitHub profile 页面以年份展示自用户创建以来所有的 contributions
// @author            kang8
// @match             https://github.com/*
// @grant             none
// @run-at            document-end
// @license           MIT
// @homepage          https://github.com/kang8/.dotfiles/tree/master/tampermonkey-scripts#show-all-contributions-by-year-in-github-profile
// @icon              https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png
// ==/UserScript==
(async function () {
  'use strict';

  const contributionsLastYearSelector =
    'div.js-yearly-contributions > div:nth-child(1)';

  await waitForElement(contributionsLastYearSelector);

  const pathArr = location.pathname.split('/');

  /**
   * match:
   * - https://github.com/kang8
   * - https://github.com/kang8/
   */
  if (
    pathArr.length === 2 ||
    (pathArr.length === 3 && pathArr[2] === '') && pathArr[1] !== ''
  ) {
    const userId = pathArr[1];

    const contributionsLastYear = document.querySelector(
      contributionsLastYearSelector,
    );

    const contributionsAllYearsDiv = document.createElement('div');
    contributionsAllYearsDiv.className = 'position-relative border';
    contributionsAllYearsDiv.id = 'contributions-all-years';
    contributionsLastYear.after(contributionsAllYearsDiv);

    const totalYearsCreated =
      document.querySelectorAll('div.js-profile-timeline-year-list > ul > li')
        .length;

    const details = document.createElement('details');
    details.className = 'py-3';

    const summary = createSummaryElement(totalYearsCreated, details);
    details.append(summary);
    contributionsAllYearsDiv.append(details);

    const thisYear = new Date().getFullYear();

    for (let index = 0; index < totalYearsCreated; index++) {
      const currentYear = thisYear - index;

      fetch(
        `/users/${userId}/contributions?from=${currentYear}-1-01&to=${currentYear}-12-31`,
        {
          method: 'GET',
        },
      )
        .then((response) => response.text())
        .then((data) => {
          const contributionsDiv = document.createRange()
            .createContextualFragment(data);
          const contributionInfo =
            contributionsDiv.querySelector('div > div:nth-child(1) > h2')
              .textContent;
          const svgCalendarGraph = contributionsDiv.querySelector(
            'div > div:nth-child(1) > div > div',
          );

          svgCalendarGraph.querySelector('div > div.float-left').innerHTML =
            contributionInfo;

          if (currentYear !== thisYear) {
            svgCalendarGraph.classList.add('border-top');
          }

          insertAndOrderToDetails(svgCalendarGraph, details, currentYear);
        });
    }
  }
})();

/**
 * @param {Element} graph
 * @param {HTMLDetailsElement} details
 * @param {number} currentYear
 */
function insertAndOrderToDetails(graph, details, currentYear) {
  const contributionsCalendarAllYear = Array.from(
    details.querySelectorAll('div.js-calendar-graph'),
  );

  if (contributionsCalendarAllYear.length === 0) {
    details.append(graph);
  } else if (contributionsCalendarAllYear.length === 1) {
    const firstCalendarYear = getYearByContributionsCalendar(
      contributionsCalendarAllYear[0],
    );
    if (currentYear > firstCalendarYear) {
      contributionsCalendarAllYear[0].before(graph);
    } else {
      contributionsCalendarAllYear[0].after(graph);
    }
  } else {
    for (
      let index = 0;
      index < contributionsCalendarAllYear.length - 1;
      index++
    ) {
      const currentYearInCalendar = getYearByContributionsCalendar(
        contributionsCalendarAllYear[index],
      );
      const nextYearInCalendar = getYearByContributionsCalendar(
        contributionsCalendarAllYear[index + 1],
      );

      if (currentYear > currentYearInCalendar) {
        contributionsCalendarAllYear[index].before(graph);
        break;
      } else if (currentYear > nextYearInCalendar) {
        contributionsCalendarAllYear[index].after(graph);
        break;
      } else if (
        index === contributionsCalendarAllYear.length - 2 &&
        currentYear < nextYearInCalendar
      ) {
        contributionsCalendarAllYear[contributionsCalendarAllYear.length - 1]
          .after(graph);
      }
    }
  }
}

/**
 * @param {number|Element} childNode
 * @returns {number}
 */
function getYearByContributionsCalendar(childNode) {
  return childNode.querySelector('div.float-left').textContent.replace(
    /\s/g,
    '',
  ).slice(-4);
}

/**
 * @param {string} selector
 */
function waitForElement(selector) {
  return new Promise((resolve) => {
    if (document.querySelector(selector)) {
      return resolve(document.querySelector(selector));
    }

    const observer = new MutationObserver(() => {
      if (document.querySelector(selector)) {
        observer.disconnect();
        resolve(document.querySelector(selector));
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
    });
  });
}

/**
 * @param {number} totalYears
 * @param {HTMLDetailsElement} details
 * @returns {HTMLElement}
 */
function createSummaryElement(totalYears, details) {
  const summary = document.createElement('summary');
  summary.className = 'px-3';
  Object.assign(summary.style, {
    display: 'flex',
    alignItems: 'center',
    cursor: 'pointer',
    padding: '10px 16px',
    fontSize: '14px',
    fontWeight: '600',
    listStyle: 'none',
    userSelect: 'none',
  });

  const calendarIcon = createSVG(
    'M4.75 0a.75.75 0 0 1 .75.75V2h5V.75a.75.75 0 0 1 1.5 0V2H13a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1h.75V.75A.75.75 0 0 1 4.75 0M3.5 7v6.5h9V7zm9-1V3.5h-9V6z',
    'octicon mr-2',
  );
  calendarIcon.style.flexShrink = '0';
  calendarIcon.style.color = 'var(--fgColor-muted, var(--color-fg-muted))';

  const titleSpan = document.createElement('span');
  titleSpan.textContent = 'All contributions by year';
  titleSpan.style.flex = '1';

  const countBadge = document.createElement('span');
  countBadge.textContent = totalYears + ' years';
  Object.assign(countBadge.style, {
    fontSize: '12px',
    fontWeight: '500',
    color: 'var(--fgColor-muted, var(--color-fg-muted))',
    backgroundColor: 'var(--bgColor-neutral-muted, var(--color-neutral-muted))',
    padding: '2px 8px',
    borderRadius: '20px',
    marginRight: '8px',
  });

  const chevron = createSVG(
    'M12.78 5.22a.749.749 0 0 1 0 1.06l-4.25 4.25a.749.749 0 0 1-1.06 0L3.22 6.28a.749.749 0 1 1 1.06-1.06L8 8.939l3.72-3.719a.749.749 0 0 1 1.06 0z',
    '',
  );
  Object.assign(chevron.style, {
    flexShrink: '0',
    color: 'var(--fgColor-muted, var(--color-fg-muted))',
    transition: 'transform 0.2s ease',
  });

  summary.addEventListener('mouseenter', () => {
    summary.style.backgroundColor =
      'var(--bgColor-neutral-muted, var(--color-neutral-muted))';
  });
  summary.addEventListener('mouseleave', () => {
    summary.style.backgroundColor = '';
  });

  details.addEventListener('toggle', () => {
    chevron.style.transform = details.open ? 'rotate(180deg)' : '';
  });

  summary.append(calendarIcon, titleSpan, countBadge, chevron);
  return summary;
}

/**
 * @param {string} pathData
 * @param {string} className
 * @returns {SVGElement}
 */
function createSVG(pathData, className) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 16 16');
  svg.setAttribute('width', '16');
  svg.setAttribute('height', '16');
  svg.setAttribute('fill', 'currentColor');
  svg.setAttribute('class', className);

  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('d', pathData);
  svg.append(path);

  return svg;
}
