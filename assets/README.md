# Brand assets

This folder holds visual assets referenced from the project's README and translated counterparts.

## Files

| File | Purpose | Where it's referenced |
|---|---|---|
| `dmc-aidriven-database-operations.png` | DMC brand hero — current logo shown at the top of every README | `README.md`, `README.es.md`, `README.de.md`, `README.ja.md` |
| `logo.svg` | Original placeholder kept as a fallback / legacy reference | _(no longer referenced; safe to remove if unused)_ |

## Updating the brand image

If you want to swap the hero image:

1. Replace `assets/dmc-aidriven-database-operations.png` with your new file (keep the same name to avoid touching the four READMEs), **or** drop a new file in and update the `<img src="...">` reference in each README.
2. Recommended dimensions: **480×140** or similar 3.4 : 1 ratio. README image renders at full markdown width; the current width attribute is `380`.
3. Keep the file under **150 KB** — large images slow GitHub rendering.
4. Prefer SVG when the brand allows; PNG ≥ 800 px wide otherwise (so retina displays still look sharp).

That's it. Every README pickup the new image automatically as long as it points at the same path.
