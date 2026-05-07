const routes = new Map();

export function registerRoute(path, mount) {
  // path like '/home' or '/show/:id'
  routes.set(path, mount);
}

export function navigate(hash) {
  if (location.hash !== '#' + hash) location.hash = hash;
}

function matchRoute(hash) {
  const cleanHash = hash.replace(/^#/, '') || '/home';
  for (const [pattern, mount] of routes) {
    const patternParts = pattern.split('/');
    const hashParts = cleanHash.split('/');
    if (patternParts.length !== hashParts.length) continue;
    const params = {};
    let ok = true;
    for (let i = 0; i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) {
        params[patternParts[i].slice(1)] = decodeURIComponent(hashParts[i]);
      } else if (patternParts[i] !== hashParts[i]) {
        ok = false; break;
      }
    }
    if (ok) return { mount, params };
  }
  return null;
}

let rootEl = null;
let currentCleanup = null;

export function startRouter(el) {
  rootEl = el;
  window.addEventListener('hashchange', render);
  render();
}

function render() {
  if (currentCleanup) currentCleanup();
  rootEl.innerHTML = '';
  const match = matchRoute(location.hash);
  if (!match) {
    rootEl.innerHTML = `<div style="color:var(--text-sec);padding:40px;text-align:center;">Route not found: ${location.hash}</div>`;
    return;
  }
  const cleanup = match.mount(rootEl, match.params);
  currentCleanup = typeof cleanup === 'function' ? cleanup : null;
}
