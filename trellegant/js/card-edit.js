/* global TrelloPowerUp, TRELLEGANT_CONFIG */
'use strict';

const t = TrelloPowerUp.iframe();

const form        = document.getElementById('card-edit-form');
const startInput  = document.getElementById('start-date');
const dueInput    = document.getElementById('due-date');
const pctInput    = document.getElementById('pct-complete');
const pctDisplay  = document.getElementById('pct-display');
const milestoneEl = document.getElementById('is-milestone');
const depList     = document.getElementById('dep-list');
const btnCancel   = document.getElementById('btn-cancel');

// ── Helpers ──────────────────────────────────────────────────────────────────

function toDateInputValue(isoString) {
  if (!isoString) return '';
  return isoString.split('T')[0];
}

function toISOString(dateValue) {
  if (!dateValue) return null;
  return new Date(dateValue).toISOString();
}

async function apiCall(path, method = 'GET', body = null) {
  const token = await t.get('member', 'private', 'token');
  const key   = TRELLEGANT_CONFIG.API_KEY;
  const url   = `https://api.trello.com/1${path}?key=${key}&token=${token}`;
  const opts  = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(url, opts);
  if (!res.ok) throw new Error(`Trello API ${method} ${path} → ${res.status}`);
  return res.json();
}

// ── Load existing data ────────────────────────────────────────────────────────

async function loadCard() {
  const [card, pct, isMilestone, deps] = await Promise.all([
    t.card('id', 'name', 'due', 'start', 'idList', 'idBoard'),
    t.get('card', 'shared', 'percentComplete'),
    t.get('card', 'shared', 'isMilestone'),
    t.get('card', 'shared', 'dependencies'),
  ]);

  startInput.value     = toDateInputValue(card.start);
  dueInput.value       = toDateInputValue(card.due);
  pctInput.value       = pct ?? 0;
  pctDisplay.textContent = `${pct ?? 0}%`;
  milestoneEl.checked  = !!isMilestone;

  await loadDependencies(card.idBoard, card.id, deps || []);

  // When milestone is toggled, lock start = due
  milestoneEl.addEventListener('change', () => {
    if (milestoneEl.checked && dueInput.value) {
      startInput.value = dueInput.value;
    }
  });
  dueInput.addEventListener('change', () => {
    if (milestoneEl.checked) startInput.value = dueInput.value;
  });

  t.sizeTo(form);
}

// ── Dependency selector ───────────────────────────────────────────────────────

async function loadDependencies(boardId, currentCardId, selectedIds) {
  depList.innerHTML = '';
  try {
    const token = await t.get('member', 'private', 'token');
    const key   = TRELLEGANT_CONFIG.API_KEY;
    const res   = await fetch(
      `https://api.trello.com/1/boards/${boardId}/cards?filter=open&key=${key}&token=${token}`
    );
    const cards = await res.json();

    const others = cards.filter(c => c.id !== currentCardId);
    if (others.length === 0) {
      depList.innerHTML = '<p class="dep-empty">No other cards on this board.</p>';
      return;
    }

    others.forEach(card => {
      const label = document.createElement('label');
      label.className = 'dep-item';

      const cb = document.createElement('input');
      cb.type    = 'checkbox';
      cb.value   = card.id;
      cb.checked = selectedIds.includes(card.id);

      label.appendChild(cb);
      label.appendChild(document.createTextNode(card.name));
      depList.appendChild(label);
    });
  } catch {
    depList.innerHTML = '<p class="dep-error">Could not load cards. Authorize first.</p>';
  }

  t.sizeTo(form);
}

// ── Progress slider live update ────────────────────────────────────────────────

pctInput.addEventListener('input', () => {
  pctDisplay.textContent = `${pctInput.value}%`;
});

// ── Save ──────────────────────────────────────────────────────────────────────

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  const btn = document.getElementById('btn-save');
  btn.disabled = true;
  btn.textContent = 'Saving…';

  try {
    const card = await t.card('id');

    // Collect selected dependency IDs
    const selectedDeps = [...depList.querySelectorAll('input[type=checkbox]:checked')]
      .map(cb => cb.value);

    // Update native card dates via REST
    const startISO = toISOString(startInput.value);
    const dueISO   = toISOString(dueInput.value);
    await apiCall(`/cards/${card.id}`, 'PUT', {
      start: startISO,
      due: dueISO,
    });

    // Update plugin data
    await Promise.all([
      t.set('card', 'shared', 'percentComplete', Number(pctInput.value)),
      t.set('card', 'shared', 'isMilestone', milestoneEl.checked),
      t.set('card', 'shared', 'dependencies', selectedDeps),
    ]);

    t.closePopup();
  } catch (err) {
    btn.disabled = false;
    btn.textContent = 'Save';
    alert(`Save failed: ${err.message}`);
  }
});

btnCancel.addEventListener('click', () => t.closePopup());

// ── Init ──────────────────────────────────────────────────────────────────────
loadCard();
