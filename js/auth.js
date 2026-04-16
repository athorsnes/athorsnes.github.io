/* global TrelloPowerUp, TRELLEGANT_CONFIG */
'use strict';

var t = TrelloPowerUp.iframe({
  appKey:  TRELLEGANT_CONFIG.API_KEY,
  appName: 'Trellegant',
});

var btnAuthorize   = document.getElementById('btn-authorize');
var btnDeauthorize = document.getElementById('btn-deauthorize');
var statusEl       = document.getElementById('auth-status');

function checkAuthState() {
  return t.getRestApi().isAuthorized().then(function(isAuthorized) {
    if (isAuthorized) {
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
  });
}

btnAuthorize.addEventListener('click', function() {
  btnAuthorize.disabled = true;
  statusEl.textContent  = 'Waiting for authorization…';
  statusEl.className    = 'auth-status';

  t.getRestApi()
    .authorize({ scope: 'read,write', expiration: 'never' })
    .then(function() {
      return checkAuthState();
    })
    .catch(function() {
      statusEl.textContent  = 'Authorization cancelled or failed.';
      statusEl.className    = 'auth-status auth-error';
      btnAuthorize.disabled = false;
    });
});

btnDeauthorize.addEventListener('click', function() {
  t.getRestApi().clearToken()
    .then(function() {
      btnDeauthorize.style.display = 'none';
      btnAuthorize.style.display   = '';
      statusEl.textContent = 'Authorization removed.';
      statusEl.className   = 'auth-status';
    });
});

checkAuthState();
t.render(checkAuthState);
