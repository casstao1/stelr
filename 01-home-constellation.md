# 01 — Home (Constellation) + Star-Tap Peek Card

The home screen of Stelr. The user lands on a deep-space constellation: their currently-watched shows are glowing 4-point stars with friend avatar orbits, and a sparse background star-field fills the canvas. **Tapping a star focuses it and slides up a peek card from the bottom** (this is the v1 interaction pattern — preserved exactly).

## Prerequisites

- `00-foundations.md` complete (`tokens.js`, `lib/star.js`, `lib/ios-frame.js`, router, index.html shell)

## Visual reference

- `Stelr v2 - Feature 1.b.html` — the v2 constellation home (use this for layout, sizing, orbit bubbles)
- `Stelr.html` — the original v1 home (use this for the star-tap peek card behavior)

Open both side-by-side while building.

## Screen layout (top → bottom)

1. **Top bar** (~y=64): left-aligned header with:
   - Title "constellation" in Georgia semibold, ~26.9px, `colors.textPri`
   - Subtitle below in DM Sans 12.3px, `colors.textSec`: "N friends across N shows" (idle) → "N friends orbiting [Title]" (show selected) → "[Name]'s orbit" (friend selected)
   - When a show or friend is selected, a ✕ dismiss capsule appears on the right (`rgba(255,255,255,0.05)` bg, hairline border) — tapping it clears selection

2. **Background star field**: ~55 small white dust dots scattered across the canvas. Keep them very subtle: opacity range **0.06–0.235**, size 0.65–1.3px. Use deterministic positions (golden-angle or the iOS formula `x = (i * 137.5) % w`, `y = (i * 97.3 + 20) % h`) so layout is stable across reloads.

3. **Show stars**: up to 8 of the user's currently-watched shows, placed at non-overlapping positions using the slot algorithm below. Each is a `StarGlowView` rendered via `renderStar()` with:
   - **Size**: 64px inactive, 74px active (when selected)
   - **Glow color**: `colors.hotGlow` for active/hot shows, `colors.coolGlow` for dormant
   - **Label**: a frosted glass capsule showing the **show title** positioned **above** the star — DM Sans ~11px medium, white 0.76 opacity, `ultraThinMaterial` background, subtle border

4. **Friend orbit bubbles**: for each friend watching a show, an avatar bubble orbits the star at **56px radius**, connected by a thin 0.6px line from the star center to the avatar edge. Each avatar is ~24px, grows to 30px when its show is selected. Friend name label appears below the avatar when the show is focused. Details in the **Orbit system** section below.

5. **ME planet** *(web prototype only — not in iOS app)*: half-circle anchored to the bottom edge.
   - Width = full 390px viewport, dome rises ~150px above the bottom edge
   - Soft coral atmospheric glow (radial-gradient halo using `colors.coralFaint`) extending ~80px above the dome
   - Surface gradient: `colors.bgElevated` → `#1a1024`
   - "ME" label on the dome surface, DM Sans 11px, letter-spacing 2px, `colors.textTert`

6. **Bottom tab bar**: see spec 06 — bottom 90px reserved.

## Star placement algorithm

8 jittered y-band slots. Each show gets deterministic per-ID jitter layered on top:

```js
const SLOTS = [
  { x: 0.51, y: 0.41 },  // center
  { x: 0.19, y: 0.14 },  // upper-left
  { x: 0.75, y: 0.07 },  // upper-right
  { x: 0.23, y: 0.84 },  // lower-left
  { x: 0.84, y: 0.76 },  // lower-right
  { x: 0.12, y: 0.55 },  // mid-left
  { x: 0.91, y: 0.43 },  // mid-right
  { x: 0.44, y: 0.69 },  // lower-center
];
// x/y are fractions of the safe content area (after applying top/bottom/side insets)
// Safe insets: top 150px (clears header), bottom 124px (clears tab bar), sides 60px
```

Apply deterministic per-show jitter using:
```js
function deterministicUnit(seed) {
  const mixed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return (mixed % 1000) / 1000;
}
// jx = (deterministicUnit(show.id * 1731 + i * 53) - 0.5) * 0.10
// jy = (deterministicUnit(show.id * 2053 + i * 79) - 0.5) * 0.12
```

## Orbit system

Each show star has friend avatars orbiting it at radius 56px. This is a core visual — do not skip.

**Orbit angle** for each friend: evenly distributed around the circle with rotation seeded by show ID, plus per-friend jitter up to 0.72 rad:
```js
function orbitAngle(index, count, friendId, showId) {
  const seed = showId * 137 + friendId * 41 + index * 23;
  if (count === 1) return deterministicUnit(seed) * 2 * Math.PI;
  const segment = (2 * Math.PI) / count;
  const rotation = (deterministicUnit(showId * 211 + count * 43) - 0.5) * Math.PI;
  const jitter = (deterministicUnit(seed) - 0.5) * 2 * Math.min(0.72, segment * 0.32);
  return -Math.PI / 2 + rotation + index * segment + jitter;
}
```

**Connector line**: 0.6px stroke from show star center to the avatar's edge. Color derived from the show's accent color at 0.22 opacity (0.03 when dimmed).

**Avatar bubble**: circle with friend initials. 24px idle, 30px when show is selected. Shows a name label below when the show is focused.

**Dimming**: when a show is selected, orbiting friends of OTHER shows dim to 0.12 opacity.

## STAR-TAP PEEK CARD (the v1 interaction — preserved exactly)

This is the **most important behavior** in this spec. It mirrors the original `Stelr.html` pattern.

### Trigger

User taps any show star.

### Behaviors that fire simultaneously

1. **Focus state on the tapped star**:
   - Selected star: full opacity, scales to 74px (active size), title capsule brightens
   - Every other star (and orbit bubbles): opacity drops to **0.15**
   - **The entire constellation map scales up 1.07×** (`transform: scale(1.07)`, spring-animated) — this creates a subtle zoom-into-focus feel
   - Background star-field stays at full opacity (sky stays alive)
   - Subtitle in header updates to "N friends orbiting [Title]"
   - ✕ dismiss button appears in the header

2. **Peek card slides up** from the bottom:
   - Position: `left: 12px, right: 12px, bottom: 128px` (sits above the tab bar)
   - z-index above the star field; below the tab bar
   - Animation: `slideup 0.32s cubic-bezier(0.32, 0, 0.16, 1)` with spring feel
   - Keyframes: `from { transform: translateY(120%); opacity: 0; }  to { transform: translateY(0); opacity: 1; }`

### Peek card content (in order, top to bottom)

```
┌─────────────────────────────────────────┐
│  [poster]  Show Title                   │
│   56×76    Genre · Year                 │
│            Two-line summary,            │
│            clamped at 2 lines…          │
│                                         │
│  ◐◐◐  Maya, Jordan +2 more              │
│                                         │
│  [   View show   ] [  ✦ Check in   ]    │
└─────────────────────────────────────────┘
```

Note: **no × button inside the card** — dismissal is via the header ✕ or tapping outside.

- **Card background**: `ultraThinMaterial` (CSS: `backdrop-filter: blur(28px) saturate(180%)`) with `rgba(255,255,255,0.075)` fill on top
- **Border**: 0.7px gradient stroke — `rgba(255,255,255,0.18)` top-left → `show.accentColor + 0.24 opacity` bottom-right
- **Border radius**: 20px
- **Padding**: 11px
- **Box shadow**: `0 10px 18px rgba(0, 0, 0, 0.28)`
- **Poster**: 56×76, radius 10. Use `data/shows.js` to look up. Overlaid with a platform label at bottom-left (DM Sans 8.4px, white 0.72). If no poster, show accent-color gradient + initial in Georgia italic.
- **Title**: Georgia italic, 16.8px, color `colors.textPri`, line-height 1.1
- **Subtitle** (genre · year): DM Sans 10.6px, `colors.textSec`, mt 3px
- **Summary**: DM Sans 11.8px, `colors.textSec`, line-height 1.35, **clamped to 2 lines** with `-webkit-line-clamp: 2`, mt 5px
- **Audience badge** (top-right of title, if watchers > 1): "N in orbit" — 10.6px, show's accent color, `accentColor + 0.12` background, radius 8
- **Watcher row** (mt 9px, bottom of content block): up to 3 friend avatars at 18px overlapped (-3px), then "Name1, Name2 +N" in DM Sans 10.6px `colors.textPri` at 0.75 opacity, +N in show accent color
- **Buttons row** (mt 8px, gap 8px):
  - **View show** — flex: 1, height 34, radius 10, bg `rgba(255,255,255,0.06)`, 0.5px hairline border, DM Sans 12.9px weight 600, color `colors.textPri`. On tap: `router.go('#planet/<id>')`.
  - **Check in** — flex: 1, height 34, radius 10, bg is the **vibe-based accent color** for the show (derive from aggregate friend scores using `colors.hotGlow` / `colors.coral` / neutral per heat level — stub with `colors.coral` until vibe system exists), text color `#0a0a14` (dark), DM Sans 12.9px weight 600. Prepend ✦ glyph or tiny 12px Star. On tap: stub `console.log('check in', id)` for now.

### Dismissal

The peek card dismisses on ANY of:
- Tap the ✕ capsule in the header
- Tap anywhere outside the card (on the dark space, on a dust dot, on the planet)
- Tap the currently-selected star again (toggle — re-tap deselects)
- Tap a different show star (opens THAT star's peek instead — cross-fade is fine)

When dismissed: stars return to full opacity, map scale returns to 1.0, peek slides back down (~280ms, no overshoot on exit). Header subtitle and ✕ button disappear.

### Tap propagation rules

- Star buttons must `e.stopPropagation()` so tapping a star doesn't trigger the dismiss-on-outside-tap on the parent.
- The peek card itself must `e.stopPropagation()` on its container so taps inside the card don't dismiss it.
- The dismiss handler lives on the screen root (`<div>` covering the whole canvas).

## State

```js
let selectedShowId = null;   // string id from data/shows.js, or null
let selectedFriendId = null; // string id, or null — friend orbit tap
```

When `selectedShowId` changes:
- Re-render the peek card (mounted/unmounted)
- Re-apply opacity to all star buttons and orbit bubbles (`selected ? 1 : (anySelected ? 0.15 : 1)`)
- Apply / remove the 1.07× map scale
- Update header subtitle and ✕ button visibility

When `selectedFriendId` changes:
- Dim all stars and orbits NOT belonging to that friend
- Show friend name labels on that friend's orbit instances
- No peek card — in the web prototype, friend-tap can open `#me` or stub with `console.log`

## Data shape (from `data/shows.js`)

```js
export const SHOWS = [
  {
    id: 'severance',
    title: 'Severance',
    genre: 'Sci-fi thriller',
    year: 2022,
    summary: 'Mark leads a team of office workers whose memories are surgically divided...',
    accentColor: '#1a3a5c',   // used for orbit lines, badge, card gradient border
    posterColor: '#1a3a5c',   // fallback poster bg
    posterInitial: 'S',
    heat: 'hot',              // 'hot' | 'cool' | 'dormant'
    platform: 'Apple TV+',
    friends: ['maya', 'jordan', 'priya'],
  },
  // ... 7 more
];

export const FRIENDS = [
  { id: 'maya', name: 'Maya', initials: 'M', hexColor: '#E8A87C' },
  // ...
];

export function showById(id) { ... }
export function friendsForShow(showId) { ... }
```

Seed with **8 shows + 6 friends**. Real titles, varied genres. Match the show set used in the v2 mockups (`stelr-data.jsx` in the project — copy from there).

## Acceptance checklist

- [ ] Page loads at `#universe` with the constellation rendered
- [ ] Left-aligned "constellation" header with dynamic subtitle; no ✕ button at rest
- [ ] 55 background dust dots, subtle opacity (0.06–0.235), deterministic positions
- [ ] 6–8 show stars rendered using `renderStar()` from spec 00 — no overlap, jittered placement
- [ ] Show stars are 64px, scale to 74px when selected
- [ ] Each show star has a frosted-glass title capsule positioned above it
- [ ] Friend orbit bubbles appear around each show star at 56px radius, connected by thin lines
- [ ] ME planet half-circle anchored to bottom with coral atmospheric glow (web-only)
- [ ] **Tapping a star** dims all OTHER stars/orbits to opacity 0.15
- [ ] **Tapping a star** scales the constellation map to 1.07×
- [ ] **Tapping a star** slides up the peek card from the bottom
- [ ] Header subtitle updates to "N friends orbiting [Title]" and ✕ button appears
- [ ] Peek card shows: poster + platform label, title, genre · year, 2-line summary, audience badge (if >1), watcher avatars+names, View show + Check in buttons
- [ ] Card has glassy backdrop blur + accent-color gradient border
- [ ] **No × button inside the card** — dismissal via header ✕ or outside tap only
- [ ] Re-tapping the active star dismisses the card (toggle)
- [ ] Tapping ✕ in header dismisses the card and restores all opacities + scale
- [ ] Tapping outside the card dismisses it
- [ ] Tapping a DIFFERENT star switches the peek to that show
- [ ] **View show** button navigates to `#planet/<id>`
- [ ] **Check in** button is wired (console.log is fine until activity spec)
- [ ] No hardcoded hex codes — all colors come from `tokens.js`
- [ ] Tap targets ≥ 44px hit area
