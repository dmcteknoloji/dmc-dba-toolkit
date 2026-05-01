# Brand assets

This folder holds visual assets referenced from the project's README and translated counterparts.

## Files

| File | Purpose | Where it's referenced |
|---|---|---|
| `logo.svg` | DMC brand logo placeholder | Top of `README.md`, `README.es.md`, `README.de.md`, `README.ja.md` |

## Replacing the placeholder logo

The current `logo.svg` is a minimalist text-based placeholder. To swap it for the real DMC brand asset:

1. Replace `assets/logo.svg` with your file (keep the `.svg` extension, or convert references to `.png`).
2. Recommended dimensions: **480×140** or similar 3.4 : 1 ratio. README image renders at full markdown width; an SVG scales cleanly.
3. Keep the file under **80 KB** — large logos slow GitHub rendering.
4. If you switch to a raster format (PNG / WebP), provide both a 1× and 2× variant for retina displays, or commit a sufficiently large PNG (≥ 800 px wide).

That's it. Every README that references `assets/logo.svg` picks up the new image automatically.
