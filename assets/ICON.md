# AggeHealBot icon

Generated with the built-in imagegen editor on 2026-11-16. Master: `AggeHealBot-icon.png`; listing: `AggeHealBot-curseforge-icon.png`; game: `../AggeHealBot/Media/Icon.tga` (128x128 uncompressed BGRA TGA). Preview: `AggeHealBot-16px-preview.png`. Resizing and format conversion use Pillow.

AggeStealthBar's satin-gold frame is the shared family reference: equal straight sides, matching chamfered corners, at most one restrained highlight per side and no scattered white flecks.

Final prompt specification: use the latest AggeStealthBar icon as the exact frame template and the previous AggeHealBot icon as a concept reference. Preserve the reference frame, black corners and square composition. Replace only the interior with a large, clear mint-green healing cross and one ivory-gold mouse cursor on a near-black green background; remove the wand and clutter, keep the cross dominant and make both silhouettes readable at 16 pixels. Keep a classic hand-painted fantasy ability-icon finish, with no text or added ornaments.

## Fantasy refinement

Built-in imagegen edit using the satin-gold AggeStealthBar icon as the mandatory border reference. Final prompt specification: preserve the exact outer frame and replace only the interior with a single open healing hand, palm toward the viewer, emerging diagonally from deep forest-green shadow. Warm ivory/gold shading, a concentrated emerald-white restorative light in the palm, a small clear healing cross made of light, and restrained green wisps around the silhouette. Fill most of the inner square with the hand, retain readability at 16 pixels and match the dramatic classic fantasy atmosphere of StealthBar. Avoid generic medical symbols, mouse cursors, wands, multiple hands, text, clutter or extra props. No addon behavior changes.

## Approved release artwork (1.1.6)

The current master is the front-facing translucent ruby-crystal cross, with the large uniformly scaled native Windows cursor composited on top and given a restrained glass/bevel material. It matches the current CurseForge logo. The in-game texture is 128x128 uncompressed BGRA TGA. The background was edited with built-in imagegen; cursor geometry and compositing are deterministic, as requested by the user.

The chosen background and full prompt are retained in `concepts/aqua-front-cross-clean.png` and `concepts/FRONT-CRYSTAL-PROMPT.md`. Reproduce using `uv run --with pillow python assets/concepts/compose_glassy_cursor.py --background aqua-front-cross-clean.png --output aqua-front-glassy-cursor` on Windows, then resize/convert the output to the canonical assets. Only selected compositing sources are committed; unused draft variants are excluded from the release.
