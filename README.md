# Resource Pack Rebuild Kit

This reproduces every manual fix we made by hand, so you can redo the whole
merge automatically whenever ONE of the source packs updates, instead of
walking through it manually again.

## How to use it

1. Get the current source files, named exactly:
   - `Matcha_Flavoured_source.zip` — the full Matcha zip (data+resource combined) from Modrinth
   - `Sparkles_source.zip` — Incendium's companion resource pack from Modrinth
   - `Stellarity_source.zip` — Stellarity's resource pack from Modrinth
   - `Matcha_Colourmap_Fix.zip` — **only needed if starting from a fresh Matcha
     download that doesn't have the colourmap fix pre-applied.** If you're
     updating from a previous run of this script, Matcha's source zip won't
     have the fix baked in either way, so keep this file present every time.

2. Put all of them in the same folder as `rebuild_pack.sh`.

3. Run: `chmod +x rebuild_pack.sh && ./rebuild_pack.sh`

4. It outputs `Matcha_Stellarity_Incendium_combined.zip` plus a `.sha1` file
   with the hash you need for `server.properties`.

## What it does, step by step

| Step | What | Why |
|---|---|---|
| 1 | Extract all three source zips | — |
| 2 | Resolve Sparkles' overlay stack | Sparkles auto-selects version folders at runtime; we bake that in manually since we're flattening to one static zip |
| 3 | Resolve Stellarity's overlay | Same idea, but Stellarity uses one exact-match overlay instead of stacking |
| 4 | Patch Matcha's water colors back to vanilla | Matcha recolors water pale gray/blue in every biome; this pulls real vanilla values from Mojang's data and patches just those two fields, keeping every other Matcha biome change intact |
| 5 | Remove custom zombie/creeper/baby-zombie textures | Falls back to vanilla mob textures automatically once removed |
| 6 | Merge in the colourmap fix | Fixes purple grass in extreme-temperature biomes (e.g. Terralith's Alpine Highlands) that Matcha's colormap doesn't cover |
| 7 | Layer everything: Stellarity → Sparkles → Matcha | Matcha wins any file conflicts, per your stated priority |
| 8 | Zip + hash | Produces the file and hash you need |

## When you'll need to EDIT the script (not just re-run it)

Most updates (a new Matcha version, a new Stellarity version, etc.) need
**no script changes at all** — just drop in the new source zip and re-run.
You only need to touch the script itself if:

- **Minecraft itself updates** (a new MC version beyond 26.2): update
  `MC_VERSION` and `PACK_FORMAT` at the top of the script. You can find the
  new pack_format number in any current pack's `pack.mcmeta`.
- **Sparkles restructures its overlays**: check its `pack.mcmeta` for the
  `overlays` section — if the folder names or format ranges listed there
  change, update the `SPARKLES_OVERLAYS` array in Step 2.
- **Stellarity restructures its overlays**: same idea — check its
  `pack.mcmeta`, update the `STELLARITY_OVERLAY` variable in Step 3 if the
  folder name for your target format changes.
- **Matcha renames/moves its zombie or creeper texture files**: update the
  `REVERT_TEXTURES` array in Step 5 if `unzip -l` shows different paths.
- **You want to revert a NEW texture or color** in the future (not just the
  ones covered here): add a new step following the same pattern — either an
  `rm` for a texture file, or a Python patch block for a JSON field.

## Quick sanity checks after running it

```bash
# confirm water colors got patched
unzip -p Matcha_Stellarity_Incendium_combined.zip data/minecraft/worldgen/biome/ocean.json | grep water_color
# should show a real blue like #3f76e4, not the pale #a2... version

# confirm mob textures were removed (should print nothing)
unzip -l Matcha_Stellarity_Incendium_combined.zip | grep -E "zombie\.png|creeper\.png|zombie_baby\.png"
```
