/* global TrelloPowerUp, TRELLEGANT_CONFIG */
'use strict';

const t = TrelloPowerUp.iframe();

const btnAuthorize   = document.getElementById('btn-authorize');
const btnDeauthorize = document.getElementById('btn-deauthorize');
const statusEl       = document.getElementById('auth-status');

const LS_KEY = 'trellegant_auth_token';

function buildAuthUrl() {
  const key = TRELLEGANT_CONFIG.API_KEY;
  const params = new URLSearchParams({
    expiration: 'never',
    scope: 'read,write',
    response_type: 'token',
    name: 'Trellegant',
    key,
    return_url: 'https://athorsnes.github.io/authorize-callback.html',
  });
  return `https://trello.com/1/authorize?${params}`;
}

async function checkAuthState() {
  const token = await t.get('member', 'private', 'token');
  if (token) {
    btnAuthorize.style.display   = 'none';
    btnDeauthorize.style.display = '';
    statusEl.textContent  = 'Authorized';
    statusEl.className    = 'auth-status auth-ok';
  } else {
    btnAuthorize.style.display   = '';
    btnDeauthorize.style.display = 'none';
    statusEl.textContent = '';
  }
  t.sizeTo(document.body);
}

btnAuthorize.addEventListener('click', () => {
  // Clear any stale token from a previous attempt
  localStorage.removeItem(LS_KEY);

  btnAuthorize.disabled = true;
  statusEl.textContent  = 'Waiting for authorization…';
  statusEl.className    = 'auth-status';

  const popup = window.open(buildAuthUrl(), 'trellegant_auth', 'width=580,height=680');

  // Poll localStorage — the callback page sets the token there
  const interval = setInterval(async () => {
    const token = localStorage.getItem(LS_KEY);

    if (token) {
      clearInterval(interval);
      localStorage.removeItem(LS_KEY);

      // Validate token looks right (Trello tokens are 64 hex chars)
      if (token.length !== 64) {
        statusEl.textContent  = 'Invalid token received. Please try again.';
        statusEl.className    = 'auth-status auth-error';
        btnAuthorize.disabled = false;
        return;
      }

      await t.set('member', 'private', 'token', token);
      checkAuthState();
      return;
    }

    // If the popup was closed without completing, stop polling
    if (!popup || popup.closed) {
      clearInterval(interval);
      statusEl.textContent  = 'Authorization cancelled.';
      statusEl.className    = 'auth-status auth-error';
      btnAuthorize.disabled = false;
    }
  }, 500);
});

btnDeauthorize.addEventListener('click', async () => {
  await t.remove('member', 'private', 'token');
  btnDeauthorize.style.display = 'none';
  btnAuthorize.style.display   = '';
  statusEl.textContent = 'Authorization removed.';
  statusEl.className   = 'auth-status';
});

checkAuthState();
t.render(checkAuthState);
