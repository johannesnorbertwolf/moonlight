// Moon icons for night buckets, as inline SVG strings. Colors come from CSS variables.

// How much of the moon is covered by the "shadow" circle, per bucket (offset of the shadow).
const SHADOW_OFFSET = { light: 0.75, medium: 0.45, heavy: 0.22 };

export function moonSvg(bucket, size = 24, { label = "", bg = "var(--bg)" } = {}) {
  const r = size / 2 - 1;
  const c = size / 2;
  const title = label ? `<title>${label}</title>` : "";
  const open = `<svg class="moon" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" role="img" aria-label="${label}">${title}`;

  if (bucket === "free") {
    return `${open}<circle cx="${c}" cy="${c}" r="${r}" fill="var(--moon)"/></svg>`;
  }
  if (bucket in SHADOW_OFFSET) {
    const dx = SHADOW_OFFSET[bucket] * size;
    return `${open}<circle cx="${c}" cy="${c}" r="${r}" fill="var(--moon)"/>` +
      `<circle cx="${c + dx}" cy="${c - dx * 0.25}" r="${r}" fill="${bg}"/></svg>`;
  }
  if (bucket === "very_heavy") {
    return `${open}<circle cx="${c}" cy="${c}" r="${r}" fill="var(--moon-dark)"/></svg>`;
  }
  if (bucket === "missing") {
    return `${open}<circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="var(--text-2)" stroke-width="1"/>` +
      `<text x="${c}" y="${c}" text-anchor="middle" dominant-baseline="central" font-size="${size * 0.5}" fill="var(--text-2)">?</text></svg>`;
  }
  // future
  return `${open}<circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="var(--moon-dark)" stroke-width="1" stroke-dasharray="2 2"/></svg>`;
}
