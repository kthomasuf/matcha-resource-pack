# Resource Pack Rebuild Kit

Reproduces every manual fix applied by hand. Run to redo the whole merge
automatically whenever one of the source packs updates, instead of repeating
the manual process.

## Usage

1. Get the current source files, named exactly:
   - `Matcha_Flavoured_source.zip` — the full Matcha zip (data+resource combined) from Modrinth
   - `Sparkles_source.zip` — Incendium's companion resource pack from Modrinth
   - `Stellarity_source.zip` — Stellarity's resource pack from Modrinth
   - `Matcha_Colourmap_Fix.zip` — only needed when starting from a fresh Matcha
     download that doesn't have the colourmap fix pre-applied. Since a fresh
     Matcha source zip never has the fix baked in, keep this file present on
     every run.

2. Place all of them in the same folder as `rebuild_pack.sh`.

3. Run: `chmod +x rebuild_pack.sh && ./rebuild_pack.sh`

4. Output: `Matcha_Stellarity_Incendium_combined.zip` plus a `.sha1` file
   containing the hash needed for `server.properties`.

## Step-by-step breakdown

| Step | What | Why |
|---|---|---|
| 1 | Extract all three source zips | — |
| 2 | Resolve Sparkles' overlay stack | Sparkles auto-selects version folders at runtime; this bakes that in manually since the output is a flattened, static zip |
| 3 | Resolve Stellarity's overlay | Same idea, but Stellarity uses one exact-match overlay instead of stacking |
| 4 | Patch Matcha's water colors back to vanilla | Matcha recolors water pale gray/blue in every biome; this pulls real vanilla values from Mojang's data and patches just those two fields, leaving every other Matcha biome change intact |
| 5 | Remove custom zombie/creeper/baby-zombie textures | Falls back to vanilla mob textures automatically once removed |
| 6 | Merge in the colourmap fix | Fixes purple grass in extreme-temperature biomes (e.g. Terralith's Alpine Highlands) that Matcha's colormap doesn't cover |
| 7 | Layer everything: Stellarity → Sparkles → Matcha | Matcha wins any file conflicts, per the configured priority |
| 8 | Zip + hash | Produces the final file and its hash |

## When the script itself needs editing (not just a re-run)

Most updates (a new Matcha version, a new Stellarity version, etc.) need no
script changes — just drop in the new source zip and re-run. Edit the script
only if:

- **Minecraft itself updates** (a new MC version beyond 26.2): update
  `MC_VERSION` and `PACK_FORMAT` at the top of the script. The new
  pack_format number is listed in any current pack's `pack.mcmeta`.
- **Sparkles restructures its overlays**: check its `pack.mcmeta` for the
  `overlays` section — if the folder names or format ranges listed there
  change, update the `SPARKLES_OVERLAYS` array in Step 2.
- **Stellarity restructures its overlays**: same idea — check its
  `pack.mcmeta`, update the `STELLARITY_OVERLAY` variable in Step 3 if the
  folder name for the target format changes.
- **Matcha renames/moves its zombie or creeper texture files**: update the
  `REVERT_TEXTURES` array in Step 5 if `unzip -l` shows different paths.
- **A new texture or color needs reverting** in the future (not just the
  ones covered here): add a new step following the same pattern — either an
  `rm` for a texture file, or a Python patch block for a JSON field.

## Sanity checks after running

```bash
# confirm water colors got patched
unzip -p Matcha_Stellarity_Incendium_combined.zip data/minecraft/worldgen/biome/ocean.json | grep water_color
# should show a real blue like #3f76e4, not the pale #a2... version

# confirm mob textures were removed (should print nothing)
unzip -l Matcha_Stellarity_Incendium_combined.zip | grep -E "zombie\.png|creeper\.png|zombie_baby\.png"
```
