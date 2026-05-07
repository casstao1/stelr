# 00 — Foundations

Project skeleton, design tokens, fonts, and the universal primitives every other spec depends on.

## Prerequisites

None. This is the first spec.

## What you're building

1. The project file structure
2. `tokens.js` — all colors, fonts, spacing, easing, sizes
3. Google Fonts loader for DM Serif Display + DM Sans
4. The `<Star>` primitive (4-point star SVG, used everywhere)
5. The iOS device frame wrapper (visual chrome around the canvas)
6. A starter `index.html` that boots the app and routes to a screen

## File structure

```
/
├── index.html                  ← app shell, loads tokens + router + active screen
├── tokens.js                   ← single source of truth for design values
├── lib/
│   ├── star.js                 ← <Star> primitive (4-point SVG)
│   ├── ios-frame.js            ← device chrome (status bar, home bar)
│   └── router.js               ← hash-based screen router (e.g. #universe, #planet/severance)
├── screens/
│   ├── universe.js             ← constellation / social home (built in spec 01)
│   ├── planet.js               ← show detail overlay (built in spec 02)
│   ├── activity.js             ← (built in spec 03)
│   ├── search.js               ← (built in spec 04)
│   └── me.js                   ← (built in spec 05)
└── data/
    └── shows.js                ← in-memory show + friend + activity data
```

Use **ES modules**: `<script type="module">` in index.html, `import`/`export` in JS files.

## tokens.js — design values

All values below MUST be exported by name from `tokens.js`. Feature code references them; never hardcodes raw values.

```js
// tokens.js — single source of truth
export const colors = {
  // Space / backgrounds
  bg:           '#070710',  // deep space, page background
  bgElevated:   '#0A0612',  // sheets, cards
  bgSubtle:     '#221E18',  // hover/pressed surfaces

  // Coral — the personal/active accent
  coral:        '#E5604A',
  coralSoft:    'rgba(229, 96, 74, 0.32)',
  coralFaint:   'rgba(229, 96, 74, 0.08)',

  // Star glows
  hotGlow:      '#EDE5D8',  // warm cream halo (active shows)
  coolGlow:     '#A8C3E8',  // silver-blue halo (dormant)
  starWhite:    '#FFFFFF',  // star fill

  // Text
  textPri:      '#EDE5D8',  // warm cream
  textSec:      '#8A8070',  // warm muted grey-brown
  textTert:     'rgba(138, 128, 112, 0.62)',
  textQuat:     'rgba(138, 128, 112, 0.38)',

  // Hairlines + dividers
  hairline:     'rgba(255, 255, 255, 0.08)',
  hairlineSoft: 'rgba(255, 255, 255, 0.05)',
};

export const fonts = {
  display: '"DM Serif Display", Georgia, serif',  // headlines, big numbers
  ui:      '"DM Sans", system-ui, sans-serif',    // labels, buttons, body
};

export const space = {
  xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 48,
};

export const radius = {
  sm: 8, md: 12, lg: 18, xl: 28, pill: 999,
};

export const ease = {
  out:   'cubic-bezier(0.2, 0.8, 0.2, 1)',
  back:  'cubic-bezier(0.34, 1.56, 0.64, 1)',  // overshoot, used for peek card slide-up
  io:    'cubic-bezier(0.4, 0, 0.2, 1)',
};

export const dur = {
  fast: 180, base: 280, slow: 420,
};

// Device viewport
export const device = { width: 390, height: 844 };
```

## Fonts

In `index.html` `<head>`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=DM+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
```

## The Star primitive — `lib/star.js`

The 4-point star is the most-used motif in the app. Build it once.

**Visual spec:**
- 4-point star with concave curves between points (a "twinkle" silhouette, not a sharp diamond)
- Vertical and horizontal points are equal length
- Renders at any pixel size; the SVG `viewBox` stays constant
- Optional glow halo: a blurred radial-gradient div behind the star
- Variants: `fill` (default white), `glow` (default warm cream), `glowSize` (in px)

**API:**

```js
// renderStar(opts) -> HTMLElement (a wrapped <div> containing svg + glow)
export function renderStar({
  size = 16,           // px — star path size
  fill = '#FFFFFF',
  glow = null,         // hex color or null for no glow
  glowSize = null,     // px halo radius; defaults to size * 0.6
}) { ... }
```

**Path data** (paste exactly into the SVG):

```
M50,5
C50,30 30,50 5,50
C30,50 50,70 50,95
C50,70 70,50 95,50
C70,50 50,30 50,5 Z
```

(That's a 100×100 viewBox; the path is the 4-point star with concave sides.)

The wrapper div should be:
- `display: inline-block`
- `position: relative`
- glow halo as an absolutely-positioned `::before` or sibling div with `filter: blur(12px)` and `radial-gradient`

## iOS frame — `lib/ios-frame.js`

A wrapper that gives any screen the device-chrome look (matches the mockups). Just visual fidelity — does not affect routing or content.

**Spec:**
- 390 × 844 inner area
- Outer rounded rectangle, `border-radius: 48px`
- Multi-layer shadow + bezel ring (see mockup CSS)
- Top status bar: time on left ("9:41"), signal/wifi/battery icons on right
- Bottom home indicator: 139 × 5 px white bar, `border-radius: 100px`, ~8 px from bottom

**API:**

```js
// mountInFrame(el) -> wraps el in the device chrome and appends to document.body
export function mountInFrame(screenEl) { ... }
```

The frame is one fixed element per page. Screens render INTO it (not as siblings).

## Router — `lib/router.js`

Hash-based, minimal:

- `#universe` → universe.js (the constellation / social home screen)
- `#planet/<id>` → planet.js (**detail overlay**, not a tab — rendered on top of universe)
- `#activity` → activity.js
- `#search` → search.js
- `#me` → me.js

**Tab bar note:** Only 4 items appear in the tab bar, matching the iOS app exactly:
- Three tabs in the pill: **Stelr** (`#universe`), **Activity** (`#activity`), **Me** (`#me`)
- One separate floating island: **Search** (`#search`)

`#planet/<id>` is never a tab — it is a detail view layered over whatever screen the user came from, dismissed to return.

API:

```js
export function go(hash) { window.location.hash = hash; }
export function onRoute(handler) { /* listens for hashchange + initial load */ }
```

The router calls `handler(routeName, params)` whenever the hash changes. Each screen module exports a `mount(params)` function the router calls.

## index.html

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=390, initial-scale=1, viewport-fit=cover"/>
  <title>Stelr</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=DM+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    html, body { margin: 0; background: #070710; height: 100%; overflow: hidden; }
    body { display: flex; align-items: center; justify-content: center; }
  </style>
</head>
<body>
  <script type="module" src="./app.js"></script>
</body>
</html>
```

`app.js` mounts the iOS frame, then wires the router to the screens.

## Acceptance checklist

- [ ] File structure matches spec exactly
- [ ] `tokens.js` exports `colors`, `fonts`, `space`, `radius`, `ease`, `dur`, `device`
- [ ] `tokens.js` is the ONLY place hex codes / pixel values live for those concepts
- [ ] DM Serif Display + DM Sans loaded from Google Fonts; verify in DevTools Network tab
- [ ] `renderStar({ size: 24, glow: colors.hotGlow })` produces a 4-point star with concave curves and a warm halo
- [ ] Star renders crisp at 8px, 16px, 32px, 64px (no pixel artifacts)
- [ ] iOS frame shows: rounded corners, status bar with time, home indicator bar
- [ ] Router responds to hash changes; default route loads universe
- [ ] Tab bar shows 3-tab pill (Stelr, Activity, Me) + separate Search island
- [ ] No raw hex codes in any file outside `tokens.js`
