import { mountFrame } from './frame.js';
import { registerRoute, startRouter } from './router.js';

const stage = document.getElementById('stage');
const screenRoot = mountFrame(stage);

// Placeholder home route — replaced in spec 01
registerRoute('/home', (root) => {
  root.innerHTML = `
    <div class="bg-stars"></div>
    <div style="
      position:absolute; inset:0;
      display:grid; place-items:center;
      color: var(--text-sec);
      font-family: var(--font-display);
      font-size: 22px;
    ">Stelr — foundations ready</div>
  `;
});

if (!location.hash) location.hash = '/home';
startRouter(screenRoot);
