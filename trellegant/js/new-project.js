/* global TrelloPowerUp, TRELLEGANT_CONFIG, PROJECT_TEMPLATE */
'use strict';

const t = TrelloPowerUp.iframe({ targetOrigin: '*' });

// ── DOM refs ──────────────────────────────────────────────────────────────────

const viewForm     = document.getElementById('view-form');
const viewProgress = document.getElementById('view-progress');
const viewSuccess  = document.getElementById('view-success');
const form         = document.getElementById('new-project-form');
const nameInput    = document.getElementById('project-name');
const descInput    = document.getElementById('project-desc');
const startInput   = document.getElementById('project-start');
const endInput     = document.getElementById('project-end');
const formError    = document.getElementById('form-error');
const progressText = document.getElementById('progress-text');
const successTitle = document.getElementById('success-title');
const successDesc  = document.getElementById('success-desc');
const btnCancel    = document.getElementById('btn-cancel');
const btnOpenBoard = document.getElementById('btn-open-board');
const btnClose     = document.getElementById('btn-close-modal');
const templateList = document.getElementById('template-items');

// ── Pre-fill defaults ─────────────────────────────────────────────────────────

(function initForm() {
  // Default start = today, end = +42 days
  const now = new Date();
  startInput.value = now.toISOString().split('T')[0];
  const end = new Date(now);
  end.setDate(end.getDate() + 42);
  endInput.value = end.toISOString().split('T')[0];

  // Populate template preview
  PROJECT_TEMPLATE.lists.forEach(list => {
    if (list.cards.length === 0) return;
    const li = document.createElement('li');
    li.innerHTML = `<strong>${escapeHtml(list.name)}</strong>`;
    const ul = document.createElement('ul');
    list.cards.forEach(card => {
      const item = document.createElement('li');
      item.textContent = card.isMilestone ? `◆ ${card.name}` : card.name;
      ul.appendChild(item);
    });
    li.appendChild(ul);
    templateList.appendChild(li);
  });

  t.sizeTo(document.body);
})();

// ── Utilities ─────────────────────────────────────────────────────────────────

function showError(msg) {
  formError.textContent = msg;
  formError.style.display = '';
}

function hideError() {
  formError.style.display = 'none';
}

function show(el) { el.style.display = ''; }
function hide(el) { el.style.display = 'none'; }

function addDays(dateStr, n) {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + n);
  return d.toISOString();
}

async function apiCall(path, method = 'GET', body = null) {
  const token = await t.get('member', 'private', 'token');
  const key   = TRELLEGANT_CONFIG.API_KEY;
  const params = new URLSearchParams({ key, token });
  const url   = `https://api.trello.com/1${path}?${params}`;
  const opts  = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(url, opts);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  }
  return res.json();
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Board creation ────────────────────────────────────────────────────────────

async function createProject(projectName, projectDesc, startDate, endDate) {
  const ctx = t.getContext();

  // 1. Create the board
  progressText.textContent = 'Creating board…';
  const boardBody = {
    name: projectName,
    desc: projectDesc || '',
    defaultLists: false,
    defaultLabels: true,
  };
  if (ctx.organization) boardBody.idOrganization = ctx.organization;

  const board = await apiCall('/boards', 'POST', boardBody);

  // 2. Create the "Milestone" label on the new board
  progressText.textContent = 'Setting up labels…';
  const milestoneLabel = await apiCall('/labels', 'POST', {
    name: 'Milestone',
    color: 'purple',
    idBoard: board.id,
  });

  // 3. Create lists from template (reversed because Trello prepends)
  progressText.textContent = 'Creating phases…';
  const listIds = {};
  for (const listDef of [...PROJECT_TEMPLATE.lists].reverse()) {
    const list = await apiCall('/lists', 'POST', {
      name: listDef.name,
      idBoard: board.id,
      pos: 'top',
    });
    listIds[listDef.name] = list.id;
  }

  // 4. Create cards from template
  const totalCards = PROJECT_TEMPLATE.lists.reduce((n, l) => n + l.cards.length, 0);
  let created = 0;

  for (const listDef of PROJECT_TEMPLATE.lists) {
    const listId = listIds[listDef.name];
    if (!listId) continue;

    for (const cardDef of listDef.cards) {
      created++;
      progressText.textContent = `Creating tasks… (${created}/${totalCards})`;

      const cardStart = addDays(startDate, cardDef.startOffset);
      const cardDue   = addDays(startDate, cardDef.dueOffset);

      const cardBody = {
        name: cardDef.name,
        idList: listId,
        start: cardStart,
        due: cardDue,
        pos: 'bottom',
      };

      if (cardDef.isMilestone) {
        cardBody.idLabels = milestoneLabel.id;
      }

      await apiCall('/cards', 'POST', cardBody);
      // Note: plugin data (isMilestone flag) cannot be set via REST API —
      // it will be applied the first time each card is opened in the Power-Up.
    }
  }

  return board;
}

// ── Form submit ───────────────────────────────────────────────────────────────

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  hideError();

  const projectName = nameInput.value.trim();
  const projectDesc = descInput.value.trim();
  const startDate   = startInput.value;
  const endDate     = endInput.value;

  if (!projectName) return showError('Project name is required.');
  if (!startDate || !endDate) return showError('Start and end dates are required.');
  if (new Date(endDate) < new Date(startDate)) return showError('End date must be after start date.');

  // Check auth
  const token = await t.get('member', 'private', 'token');
  if (!token) {
    return showError('You need to authorize Trellegant first. Go to Power-Up Settings → Authorize Trellegant.');
  }

  // Switch to progress view
  hide(viewForm);
  show(viewProgress);

  try {
    const board = await createProject(projectName, projectDesc, startDate, endDate);

    // Switch to success view
    hide(viewProgress);
    show(viewSuccess);
    successTitle.textContent = `"${projectName}" created!`;
    successDesc.textContent  = `Your board has been set up with ${PROJECT_TEMPLATE.lists.reduce((n, l) => n + l.cards.length, 0)} tasks across ${PROJECT_TEMPLATE.lists.filter(l => l.cards.length > 0).length} phases.`;

    btnOpenBoard.addEventListener('click', () => {
      t.navigate({ url: board.url });
      t.closeModal();
    });

  } catch (err) {
    hide(viewProgress);
    show(viewForm);
    showError(`Failed to create project: ${err.message}`);
  }
});

// ── Cancel / close ────────────────────────────────────────────────────────────

btnCancel.addEventListener('click', () => t.closeModal());
btnClose.addEventListener('click',  () => t.closeModal());
