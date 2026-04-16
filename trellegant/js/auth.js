/* global TrelloPowerUp, TRELLEGANT_CONFIG */
'use strict';

const t = TrelloPowerUp.iframe();

const btnAuthorize = document.getElementById('btn-authorize');
const btnDeauthorize = document.getElementById('btn-deauthorize');
const statusEl = document.getElementById('auth-status');

function buildAuthUrl() {
  const key = TRELLEGANT_CONFIG.API_KEY;
  const params = new URLSearchParams({
    expiration: 'never',
    scope: 'read,write',
    response_type: 'token',
    name: 'Trellegant',
    key,
    return_url: window.location.origin,
  });
  return `https://trello.com/1/authorize?${params}`;
}

async function checkAuthState() {
  const token = await t.get('member', 'private', 'token');
  if (token) {
    btnAuthorize.style.display = 'none';
    btnDeauthorize.style.display = '';
    statusEl.textContent = 'Authorized';
    statusEl.className = 'auth-status auth-ok';
  } else {
    btnAuthorize.style.display = '';
    btnDeauthorize.style.display = 'none';
    statusEl.textContent = '';
  }
}

btnAuthorize.addEventListener('click', async () => {
  btnAuthorize.disabled = true;
  statusEl.textContent = 'Waiting for authorization…';
  statusEl.className = 'auth-status';

  try {
    const token = await t.authorize(buildAuthUrl(), {
      height: 680,
      width: 580,
      validToken: (token) => typeof token === 'string' && token.length === 64,
    });
    await t.set('member', 'private', 'token', token);
    statusEl.textContent = 'Authorized successfully!';
    statusEl.className = 'auth-status auth-ok';
    btnAuthorize.style.display = 'none';
    btnDeauthorize.style.display = '';
  } catch (err) {
    statusEl.textContent = 'Authorization cancelled or failed.';
    statusEl.className = 'auth-status auth-error';
    btnAuthorize.disabled = false;
  }
});

btnDeauthorize.addEventListener('click', async () => {
  await t.remove('member', 'private', 'token');
  btnDeauthorize.style.display = 'none';
  btnAuthorize.style.display = '';
  statusEl.textContent = 'Authorization removed.';
  statusEl.className = 'auth-status';
});

// Init
checkAuthState();
t.render(checkAuthState);
