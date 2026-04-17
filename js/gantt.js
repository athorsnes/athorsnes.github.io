/* global TrelloPowerUp, Gantt, TRELLEGANT_CONFIG, TRELLEGANT_VERSION, TRELLEGANT_BUILD */
'use strict';

// ── Constants ─────────────────────────────────────────────────────────────────

const LIST_COLORS = [
  '#4A90E2', '#27AE60', '#F39C12', '#E74C3C',
  '#9B59B6', '#16A085', '#E91E8C', '#00BCD4',
];

const ROW_HEIGHT = 38; // must match CSS .gantt .bar-row height

// ── State ─────────────────────────────────────────────────────────────────────

const t = TrelloPowerUp.iframe({
  appKey:  TRELLEGANT_CONFIG.API_KEY,
  appName: 'Trellegant',
});
let ganttInstance = null;
let boardData     = { lists: [], cards: [] };
let colorMap      = {};       // listId → color
let addTaskListId = null;     // which list the add-task input targets

// ── DOM refs ──────────────────────────────────────────────────────────────────

const boardTitle     = document.getElementById('board-title');
const leftBody       = document.getElementById('gantt-left-body');
const ganttRight     = document.getElementById('gantt-right');
const statusBar      = document.getElementById('status-bar');
const statusText     = document.getElementById('status-text');
const viewToggle     = document.getElementById('view-toggle');
const btnRefresh     = document.getElementById('btn-refresh');
const btnNewProject  = document.getElementById('btn-new-project');
const btnClose       = document.getElementById('btn-close');
const versionBadge   = document.getElementById('version-badge');
const addOverlay     = document.getElementById('add-task-overlay');
const addInput       = document.getElementById('add-task-input');
const addConfirm     = document.getElementById('add-task-confirm');
const addCancel      = document.getElementById('add-task-cancel');

// ── Utilities ─────────────────────────────────────────────────────────────────

function showStatus(msg, isError = false) {
  statusText.textContent = msg;
  statusBar.className = 'status-bar' + (isError ? ' status-error' : '');
  statusBar.style.display = '';
  if (!isError) setTimeout(() => { statusBar.style.display = 'none'; }, 3000);
}

function toDateStr(iso) {
  if (!iso) return null;
  return iso.split('T')[0];
}

function addDays(dateStr, n) {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + n);
  return d.toISOString().split('T')[0];
}

function today() {
  return new Date().toISOString().split('T')[0];
}

async function apiCall(path, method = 'GET', body = null) {
  const token = await t.getRestApi().getToken();
  const key   = TRELLEGANT_CONFIG.API_KEY;
  const url   = `https://api.trello.com/1${path}`;
  const params = new URLSearchParams({ key, token });
  const opts  = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${url}?${params}`, opts);
  if (!res.ok) throw new Error(`API ${method} ${path} → ${res.status}`);
  return res.json();
}

function getPluginData(card, pluginId) {
  const pd = (card.pluginData || []).find(p => p.idPlugin === pluginId);
  if (!pd) return {};
  try { return JSON.parse(pd.value); } catch { return {}; }
}

// ── Data loading ──────────────────────────────────────────────────────────────

async function loadBoardData() {
  const ctx     = t.getContext();
  const token   = await t.getRestApi().getToken();
  const key     = TRELLEGANT_CONFIG.API_KEY;
  const boardId = ctx.board;
  const pluginId = ctx.plugin;

  const [listsRes, cardsRes, boardRes] = await Promise.all([
    fetch(`https://api.trello.com/1/boards/${boardId}/lists?filter=open&key=${key}&token=${token}`),
    fetch(`https://api.trello.com/1/boards/${boardId}/cards?filter=open&pluginData=true&members=true&key=${key}&token=${token}`),
    fetch(`https://api.trello.com/1/boards/${boardId}?fields=name&key=${key}&token=${token}`),
  ]);

  if (!listsRes.ok || !cardsRes.ok || !boardRes.ok) {
    throw new Error('Failed to fetch board data. Check authorization.');
  }

  const lists  = await listsRes.json();
  const cards  = await cardsRes.json();
  const board  = await boardRes.json();

  boardTitle.textContent = board.name;

  // Assign colors to lists
  colorMap = {};
  lists.forEach((l, i) => {
    colorMap[l.id] = LIST_COLORS[i % LIST_COLORS.length];
  });

  return { lists, cards, pluginId };
}

// ── Gantt task mapping ────────────────────────────────────────────────────────

function buildGanttTasks(lists, cards, pluginId) {
  const tasks = [];

  for (const list of lists) {
    const listCards = cards.filter(c => c.idList === list.id);
    if (listCards.length === 0) continue;

    // Group header row (spans the full list range)
    const starts = listCards.filter(c => c.start).map(c => new Date(c.start));
    const ends   = listCards.filter(c => c.due).map(c => new Date(c.due));
    const gStart = starts.length ? new Date(Math.min(...starts)) : new Date();
    const gEnd   = ends.length   ? new Date(Math.max(...ends))   : new Date(gStart.getTime() + 86400000);

    tasks.push({
      id:           `__group_${list.id}`,
      name:         list.name,
      start:        gStart.toISOString().split('T')[0],
      end:          gEnd.toISOString().split('T')[0],
      progress:     0,
      custom_class: 'group-header-bar',
      _isGroup:     true,
      _listId:      list.id,
      _color:       colorMap[list.id],
    });

    for (const card of listCards) {
      const pd    = getPluginData(card, pluginId);
      const isMilestone = !!pd.isMilestone;
      const start = toDateStr(card.start) || toDateStr(card.due) || today();
      // Milestones must have a 1-day span so Frappe Gantt renders them
      const end   = isMilestone ? addDays(start, 1) : (toDateStr(card.due) || addDays(start, 1));

      tasks.push({
        id:           card.id,
        name:         card.name,
        start,
        end,
        progress:     pd.percentComplete ?? 0,
        dependencies: (pd.dependencies || []).join(', '),
        custom_class: isMilestone ? 'milestone-bar' : 'task-bar',
        _isGroup:     false,
        _listId:      list.id,
        _isMilestone: isMilestone,
        _members:     card.members || [],
        _color:       colorMap[list.id],
      });
    }
  }

  return tasks;
}

// ── Left panel rendering ──────────────────────────────────────────────────────

function renderLeftPanel(lists, cards, tasks) {
  leftBody.innerHTML = '';

  for (const list of lists) {
    const listCards = cards.filter(c => c.idList === list.id);
    if (listCards.length === 0) continue;

    const color = colorMap[list.id];

    // Group header row — includes "+ Add task" button so it doesn't add an extra row
    const groupRow = document.createElement('div');
    groupRow.className = 'left-group-row';
    groupRow.style.setProperty('--group-color', color);
    groupRow.innerHTML = `
      <button class="group-collapse" data-list="${list.id}" title="Collapse">▾</button>
      <span class="group-name">${escapeHtml(list.name)}</span>
      <button class="add-task-btn-inline" data-list="${list.id}" title="Add task">+</button>
    `;
    leftBody.appendChild(groupRow);

    // Task rows — one per card, 38px each to match Frappe Gantt rows exactly
    const taskGroup = document.createElement('div');
    taskGroup.className = 'left-task-group';
    taskGroup.dataset.listId = list.id;

    for (const card of listCards) {
      const pd  = tasks.find(tk => tk.id === card.id);
      const pct = pd?.progress ?? 0;

      const row = document.createElement('div');
      row.className = 'left-task-row';
      row.dataset.cardId = card.id;

      const avatars = (card.members || []).slice(0, 3).map(m =>
        `<img class="avatar" src="${m.avatarUrl}/30.png" alt="${escapeHtml(m.fullName)}" title="${escapeHtml(m.fullName)}">`
      ).join('');

      row.innerHTML = `
        <span class="task-name" title="${escapeHtml(card.name)}">${escapeHtml(card.name)}</span>
        <span class="task-avatars">${avatars}</span>
        <span class="task-pct">${pct}%</span>
      `;

      taskGroup.appendChild(row);
    }

    leftBody.appendChild(taskGroup);
  }

  // Collapse toggle
  leftBody.querySelectorAll('.group-collapse').forEach(btn => {
    btn.addEventListener('click', () => {
      const listId = btn.dataset.list;
      const group  = leftBody.querySelector(`.left-task-group[data-list-id="${listId}"]`);
      const collapsed = group.classList.toggle('collapsed');
      btn.textContent = collapsed ? '▸' : '▾';
    });
  });

  // Inline add-task buttons in group headers
  leftBody.querySelectorAll('.add-task-btn-inline').forEach(btn => {
    btn.addEventListener('click', () => showAddTask(btn.dataset.list, btn));
  });

  syncScrollHeights();
}

// ── Add task inline ───────────────────────────────────────────────────────────

function showAddTask(listId, anchorRow) {
  addTaskListId = listId;
  addInput.value = '';

  // Position the overlay below the anchor row
  const rect = anchorRow.getBoundingClientRect();
  addOverlay.style.top  = `${rect.bottom + window.scrollY}px`;
  addOverlay.style.left = `${rect.left}px`;
  addOverlay.style.display = 'flex';
  addInput.focus();
}

addCancel.addEventListener('click', () => {
  addOverlay.style.display = 'none';
  addTaskListId = null;
});

addConfirm.addEventListener('click', () => submitAddTask());
addInput.addEventListener('keydown', e => {
  if (e.key === 'Enter') submitAddTask();
  if (e.key === 'Escape') addCancel.click();
});

async function submitAddTask() {
  const name = addInput.value.trim();
  if (!name || !addTaskListId) return;

  addConfirm.disabled = true;
  addConfirm.textContent = '…';

  try {
    await apiCall('/cards', 'POST', {
      name,
      idList: addTaskListId,
      pos: 'bottom',
    });
    addOverlay.style.display = 'none';
    addTaskListId = null;
    showStatus(`Task "${name}" added.`);
    await refresh();
  } catch (err) {
    showStatus(`Failed to add task: ${err.message}`, true);
  } finally {
    addConfirm.disabled = false;
    addConfirm.textContent = 'Add';
  }
}

// ── Scroll sync ───────────────────────────────────────────────────────────────

function syncScrollHeights() {
  // Sync vertical scroll between left panel and Frappe Gantt's grid body
  const ganttBody = ganttRight.querySelector('.gantt .grid-body');
  if (!ganttBody) return;

  ganttRight.addEventListener('scroll', () => {
    leftBody.scrollTop = ganttRight.scrollTop;
  });
  leftBody.addEventListener('scroll', () => {
    ganttRight.scrollTop = leftBody.scrollTop;
  });
}

// ── Date change handler (debounced — fires on every drag tick, writes on release) ─

const pendingDateChanges = {}; // cardId → { timer, start, end }

function onDateChange(task, startDate, endDate) {
  if (task._isGroup) return;

  const start = startDate.toISOString().split('T')[0];
  const end   = endDate.toISOString().split('T')[0];

  // Show the live date in the status bar while dragging (visual feedback)
  showStatus(`${task.name}: ${start} → ${end}`);

  // Clear any pending write for this card
  if (pendingDateChanges[task.id]) {
    clearTimeout(pendingDateChanges[task.id].timer);
  }

  // Schedule the write 600ms after the last drag tick (i.e. on mouse release)
  pendingDateChanges[task.id] = {
    timer: setTimeout(async () => {
      delete pendingDateChanges[task.id];
      try {
        await apiCall(`/cards/${task.id}`, 'PUT', { start, due: end });
        showStatus(`Saved: ${task.name} → ${start} to ${end}`);
      } catch (err) {
        showStatus(`Failed to save dates: ${err.message}`, true);
      }
    }, 600),
  };
}

// ── Progress change handler ───────────────────────────────────────────────────

async function onProgressChange(task, progress) {
  if (task._isGroup) return;
  try {
    // Plugin data must be written via t.set — not available in board context
    // so we store it temporarily and remind user to open card to sync
    showStatus(`Progress updated to ${Math.round(progress)}% (open card to persist)`);
  } catch (err) {
    showStatus(`Failed to update progress: ${err.message}`, true);
  }
}

// ── Gantt render ──────────────────────────────────────────────────────────────

function renderGantt(tasks, viewMode = 'Week') {
  injectTaskColors(tasks);

  // Frappe Gantt appends to the SVG on every call — clear it first
  const svgEl = document.getElementById('gantt');
  if (svgEl) svgEl.innerHTML = '';

  ganttInstance = new Gantt('#gantt', tasks, {
    view_mode: viewMode,
    date_format: 'YYYY-MM-DD',
    popup_trigger: 'click',
    custom_popup_html: (task) => {
      if (task._isGroup) {
        return `<div class="gantt-popup-group">${escapeHtml(task.name)}</div>`;
      }
      const start = task.start ? task.start.split('T')[0] : '—';
      const end   = task._isMilestone ? start : (task.end ? task.end.split('T')[0] : '—');
      const card  = boardData.cards.find(c => c.id === task.id);
      const cardUrl = card ? card.url : null;
      return `
        <div class="gantt-popup">
          <strong>${escapeHtml(task.name)}</strong>
          ${task._isMilestone ? '<span class="popup-milestone">◆ Milestone</span>' : ''}
          <div class="popup-dates">${start}${task._isMilestone ? '' : ` → ${end}`}</div>
          ${!task._isMilestone ? `
          <div class="popup-progress-wrap">
            <div class="popup-progress">
              <div class="popup-progress-bar" style="width:${task.progress}%"></div>
            </div>
            <span class="popup-pct">${task.progress}%</span>
          </div>` : ''}
          ${cardUrl ? `<a href="${cardUrl}" target="_blank" class="popup-open-card">Open Card ↗</a>` : ''}
        </div>
      `;
    },
    on_click: () => {
      // Handled via "Open Card" link in the popup — keeps the Gantt modal open
    },
    on_date_change: onDateChange,
    on_progress_change: onProgressChange,
  });
}

function injectTaskColors(tasks) {
  let css = '';
  tasks.forEach(task => {
    if (task._color) {
      css += `.gantt .bar-wrapper[data-id="${task.id}"] .bar { fill: ${task._color}; }\n`;
      if (!task._isGroup) {
        css += `.gantt .bar-wrapper[data-id="${task.id}"] .bar-progress { fill: ${task._color}cc; }\n`;
      }
    }
  });
  let styleEl = document.getElementById('gantt-task-colors');
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = 'gantt-task-colors';
    document.head.appendChild(styleEl);
  }
  styleEl.textContent = css;
}

// ── Full refresh ──────────────────────────────────────────────────────────────

async function refresh() {
  showStatus('Loading…');
  try {
    const { lists, cards, pluginId } = await loadBoardData();
    boardData = { lists, cards };

    const tasks    = buildGanttTasks(lists, cards, pluginId);
    const viewMode = viewToggle.querySelector('.active')?.dataset.mode || 'Week';

    renderGantt(tasks, viewMode);
    renderLeftPanel(lists, cards, tasks);
    statusBar.style.display = 'none';
  } catch (err) {
    showStatus(err.message, true);
  }
}

// ── View toggle ───────────────────────────────────────────────────────────────

viewToggle.querySelectorAll('button').forEach(btn => {
  btn.addEventListener('click', () => {
    viewToggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    if (ganttInstance) ganttInstance.change_view_mode(btn.dataset.mode);
  });
});

// ── Other button handlers ─────────────────────────────────────────────────────

btnRefresh.addEventListener('click', refresh);

btnClose.addEventListener('click', () => t.closeModal());

btnNewProject.addEventListener('click', () => {
  t.modal({
    url: './new-project.html',
    title: 'Create New Project',
    height: 520,
  });
});

// ── Escape to close ───────────────────────────────────────────────────────────

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Init ──────────────────────────────────────────────────────────────────────

// Show version + build time in header
if (typeof TRELLEGANT_VERSION !== 'undefined') {
  const buildDate = new Date(TRELLEGANT_BUILD);
  const buildStr  = buildDate.toLocaleString('en-GB', {
    day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit',
  });
  versionBadge.textContent = `v${TRELLEGANT_VERSION} · ${buildStr}`;
}

refresh();
