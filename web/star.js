// 4-point star — three silhouette variants on a 24×24 viewBox, centered (12,12)
export const STAR_PATHS = {
  classic: 'M12 1 L14 10 L23 12 L14 14 L12 23 L10 14 L1 12 L10 10 Z',
  sharp:   'M12 0.5 L13.2 10.8 L23.5 12 L13.2 13.2 L12 23.5 L10.8 13.2 L0.5 12 L10.8 10.8 Z',
  twinkle: 'M12 1 C12.5 10 13.5 11.5 23 12 C13.5 12.5 12.5 14 12 23 C11.5 14 10.5 12.5 1 12 C10.5 11.5 11.5 10 12 1 Z',
};

/**
 * Returns an SVG element for a star.
 * @param {Object} opts
 * @param {number} opts.size       px size (default 16)
 * @param {string} opts.fill       fill color (default #fff)
 * @param {number} opts.glow       drop-shadow blur radius in px (default 0)
 * @param {string} opts.glowColor  glow color (default #fff)
 * @param {string} opts.variant    'classic' | 'sharp' | 'twinkle' (default 'sharp')
 */
export function makeStar({
  size = 16,
  fill = '#fff',
  glow = 0,
  glowColor = '#fff',
  variant = 'sharp',
} = {}) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', size);
  svg.setAttribute('height', size);
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.style.display = 'block';
  if (glow > 0) {
    svg.style.filter = `drop-shadow(0 0 ${glow}px ${glowColor})`;
  }
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('d', STAR_PATHS[variant]);
  path.setAttribute('fill', fill);
  svg.appendChild(path);
  return svg;
}
