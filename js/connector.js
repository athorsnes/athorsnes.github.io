/* global TrelloPowerUp */
'use strict';

const LIST_COLORS = [
  '#4A90E2', '#27AE60', '#F39C12', '#E74C3C',
  '#9B59B6', '#16A085', '#E91E8C', '#00BCD4',
];

TrelloPowerUp.initialize({

  // ── Board Buttons ──────────────────────────────────────────────────────────

  'board-buttons': (t) => {
    return [
      {
        icon: { dark: './icons/gantt-dark.svg', light: './icons/gantt-light.svg' },
        text: 'Gantt',
        callback: (t) => t.modal({
          url: './gantt.html',
          title: 'Trellegant – Gantt Chart',
          fullscreen: true,
        }),
      },
      {
        icon: { dark: './icons/new-project-dark.svg', light: './icons/new-project-light.svg' },
        text: 'New Project',
        callback: (t) => t.modal({
          url: './new-project.html',
          title: 'Create New Project',
          height: 520,
        }),
      },
    ];
  },

  // ── Card Buttons ───────────────────────────────────────────────────────────

  'card-buttons': (t) => {
    return [
      {
        icon: './icons/gantt-light.svg',
        text: 'Gantt Details',
        callback: (t) => t.popup({
          title: 'Gantt Details',
          url: './card-edit.html',
          height: 380,
        }),
      },
    ];
  },

  // ── Card Badges (front of card on the board) ───────────────────────────────

  'card-badges': (t) => {
    return Promise.all([
      t.get('card', 'shared', 'percentComplete'),
      t.get('card', 'shared', 'isMilestone'),
    ]).then(([pct, isMilestone]) => {
      const badges = [];

      if (isMilestone) {
        badges.push({
          text: '◆ Milestone',
          color: 'purple',
        });
      }

      if (pct !== undefined && pct !== null) {
        badges.push({
          text: `${pct}%`,
          color: pct === 100 ? 'green' : pct > 0 ? 'yellow' : 'light-gray',
          icon: './icons/progress.svg',
        });
      }

      return badges;
    });
  },

  // ── Card Detail Badges (back of card) ─────────────────────────────────────

  'card-detail-badges': (t) => {
    return Promise.all([
      t.get('card', 'shared', 'percentComplete'),
      t.get('card', 'shared', 'isMilestone'),
      t.get('card', 'shared', 'dependencies'),
    ]).then(([pct, isMilestone, deps]) => {
      const badges = [];

      if (isMilestone) {
        badges.push({ title: 'Type', text: '◆ Milestone', color: 'purple' });
      }

      badges.push({
        title: 'Progress',
        text: pct !== undefined && pct !== null ? `${pct}%` : 'Not set',
        color: pct === 100 ? 'green' : pct > 0 ? 'yellow' : 'light-gray',
        callback: (t) => t.popup({
          title: 'Gantt Details',
          url: './card-edit.html',
          height: 380,
        }),
      });

      if (deps && deps.length > 0) {
        badges.push({
          title: 'Dependencies',
          text: `${deps.length} task${deps.length > 1 ? 's' : ''}`,
          color: 'light-gray',
        });
      }

      return badges;
    });
  },

  // ── Authorization ──────────────────────────────────────────────────────────

  'authorization-status': (t) => {
    return t.getRestApi().isAuthorized()
      .then((isAuthorized) => ({ authorized: isAuthorized }));
  },

  'show-authorization': (t) => {
    return t.popup({
      title: 'Authorize Trellegant',
      url: './auth.html',
      height: 220,
    });
  },

}, {
  appKey: typeof TRELLEGANT_CONFIG !== 'undefined' ? TRELLEGANT_CONFIG.API_KEY : '',
  appName: 'Trellegant',
});
