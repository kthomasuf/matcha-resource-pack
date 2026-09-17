#!/bin/bash
# =============================================================================
# Combined Resource Pack Rebuild Script
# =============================================================================
# Rebuilds the merged Matcha + Stellarity + Sparkles(Incendium) resource pack
# from scratch, including all custom fixes. Run this any time ONE of the
# source packs updates -- just replace that pack's zip in this folder and
# re-run the whole script. It's idempotent (safe to run repeatedly).
#
# USAGE:
#   1. Place the current versions of these three files in this folder:
#        - Matcha_Flavoured_source.zip   (the combined Matcha data+resource zip)
#        - Sparkles_source.zip           (Incendium's companion resource pack)
#        - Stellarity_source.zip         (Stellarity's resource pack)
#   2. ./rebuild_pack.sh
#   3. Output: Matcha_Stellarity_Incendium_combined.zip + its .sha1 file
#
# PRIORITY ORDER (later wins on file conflicts): Stellarity -> Sparkles -> Matcha
# =============================================================================

set -e  # stop on any error

MC_VERSION="26.2"
PACK_FORMAT="88"   # Minecraft 26.2's pack_format -- update this when MC updates

WORKDIR="$(pwd)/_rebuild_work"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "== Step 1: Extracting source packs =="
mkdir -p "$WORKDIR/matcha_raw" "$WORKDIR/sparkles_raw" "$WORKDIR/stellarity_raw"
unzip -oq Matcha_Flavoured_source.zip -d "$WORKDIR/matcha_raw"
unzip -oq Sparkles_source.zip -d "$WORKDIR/sparkles_raw"
unzip -oq Stellarity_source.zip -d "$WORKDIR/stellarity_raw"

# -----------------------------------------------------------------------------
# Step 2: Resolve Sparkles' overlay system (CUMULATIVE overlays)
# Sparkles stacks multiple overlay folders on top of its base "assets/" folder
# depending on Minecraft's pack_format. As of 26.2 (format 88), ALL of these
# apply in this order (check Sparkles' own pack.mcmeta "overlays" section if
# it updates -- the folder names/ranges may change):
# -----------------------------------------------------------------------------
echo "== Step 2: Resolving Sparkles overlays for MC $MC_VERSION (format $PACK_FORMAT) =="
mkdir -p "$WORKDIR/sparkles_resolved"
cp -r "$WORKDIR/sparkles_raw/assets" "$WORKDIR/sparkles_resolved/" 2>/dev/null || true

SPARKLES_OVERLAYS=("1-20-5-overlay" "1-21-4-overlay" "1-21-9-overlay" "26-1-overlay")
for overlay in "${SPARKLES_OVERLAYS[@]}"; do
  if [ -d "$WORKDIR/sparkles_raw/$overlay/assets" ]; then
    cp -r "$WORKDIR/sparkles_raw/$overlay/assets" "$WORKDIR/sparkles_resolved/"
    echo "  applied: $overlay"
  else
    echo "  WARNING: expected overlay '$overlay' not found -- pack structure may have changed, check pack.mcmeta"
  fi
done

# -----------------------------------------------------------------------------
# Step 3: Resolve Stellarity's overlay system (EXCLUSIVE overlays -- only ONE
# applies, matched by exact pack_format)
# -----------------------------------------------------------------------------
echo "== Step 3: Resolving Stellarity overlay for format $PACK_FORMAT =="
mkdir -p "$WORKDIR/stellarity_resolved"
cp -r "$WORKDIR/stellarity_raw/assets" "$WORKDIR/stellarity_resolved/"

STELLARITY_OVERLAY="overlay_26_2"   # UPDATE this if pack_format changes -- check pack.mcmeta's "overlays" entries for which directory matches format 88 (or the new format)
if [ -d "$WORKDIR/stellarity_raw/$STELLARITY_OVERLAY/assets" ]; then
  cp -r "$WORKDIR/stellarity_raw/$STELLARITY_OVERLAY/assets" "$WORKDIR/stellarity_resolved/"
  echo "  applied: $STELLARITY_OVERLAY"
else
  echo "  WARNING: expected overlay '$STELLARITY_OVERLAY' not found -- check Stellarity's pack.mcmeta, the correct overlay folder name may have changed"
fi

# -----------------------------------------------------------------------------
# Step 4: Patch Matcha's water colors back to vanilla
# Matcha overrides water_color/water_fog_color in every biome's JSON to a pale
# gray-blue palette. This fetches ACTUAL vanilla values for the current MC
# version from misode's mcmeta mirror and patches just those two fields back,
# leaving every other Matcha biome change (mob spawns, particles, etc.) intact.
# -----------------------------------------------------------------------------
echo "== Step 4: Patching Matcha's water colors back to vanilla =="
BIOME_DIR="$WORKDIR/matcha_raw/data/minecraft/worldgen/biome"
VANILLA_DIR="$WORKDIR/vanilla_biomes"
mkdir -p "$VANILLA_DIR"

if [ -d "$BIOME_DIR" ]; then
  for f in "$BIOME_DIR"/*.json; do
    fname=$(basename "$f")
    curl -sL -o "$VANILLA_DIR/$fname" "https://raw.githubusercontent.com/misode/mcmeta/${MC_VERSION}-data/data/minecraft/worldgen/biome/$fname"
    python3 -c "import json; json.load(open('$VANILLA_DIR/$fname'))" 2>/dev/null || rm -f "$VANILLA_DIR/$fname"
  done

  python3 << PYEOF
import json, os

matcha_dir = "$BIOME_DIR"
vanilla_dir = "$VANILLA_DIR"
changed = 0

for fname in sorted(os.listdir(matcha_dir)):
    vanilla_path = os.path.join(vanilla_dir, fname)
    if not os.path.exists(vanilla_path):
        continue
    matcha_path = os.path.join(matcha_dir, fname)
    with open(matcha_path) as f:
        matcha_data = json.load(f)
    with open(vanilla_path) as f:
        vanilla_data = json.load(f)

    v_effects = vanilla_data.get("effects", {})
    m_effects = matcha_data.get("effects", {})
    if "water_color" not in v_effects:
        continue

    if m_effects.get("water_color") != v_effects.get("water_color") or \\
       m_effects.get("water_fog_color") != v_effects.get("water_fog_color"):
        m_effects["water_color"] = v_effects.get("water_color")
        if "water_fog_color" in v_effects:
            m_effects["water_fog_color"] = v_effects.get("water_fog_color")
        matcha_data["effects"] = m_effects
        with open(matcha_path, "w") as f:
            json.dump(matcha_data, f, indent=2)
        changed += 1

print(f"  patched {changed} biome files")
PYEOF
else
  echo "  WARNING: biome folder not found at expected path -- Matcha's file structure may have changed"
fi

# -----------------------------------------------------------------------------
# Step 5: Remove Matcha's custom mob textures (revert to vanilla)
# -----------------------------------------------------------------------------
echo "== Step 5: Removing custom zombie/creeper textures (revert to vanilla) =="
REVERT_TEXTURES=(
  "assets/minecraft/textures/entity/zombie/zombie.png"
  "assets/minecraft/textures/entity/zombie/zombie_baby.png"
  "assets/minecraft/textures/entity/creeper/creeper.png"
)
for tex in "${REVERT_TEXTURES[@]}"; do
  if [ -f "$WORKDIR/matcha_raw/$tex" ]; then
    rm -f "$WORKDIR/matcha_raw/$tex"
    echo "  removed: $tex"
  fi
done

# -----------------------------------------------------------------------------
# Step 6: Merge the Colourmap Fix into Matcha (if the fix zip is present)
# Only needed if you're starting from a FRESH Matcha download that doesn't
# already have the fix applied. Skip if Matcha_Colourmap_Fix.zip isn't present.
# -----------------------------------------------------------------------------
if [ -f "Matcha_Colourmap_Fix.zip" ]; then
  echo "== Step 6: Applying Matcha colourmap fix =="
  mkdir -p "$WORKDIR/colourmap_fix"
  unzip -oq Matcha_Colourmap_Fix.zip -d "$WORKDIR/colourmap_fix"
  # Only copy the two colormap textures -- NOT pack.mcmeta/pack.png (those must
  # stay Matcha's originals, which include an important recipe/advancement filter)
  cp "$WORKDIR/colourmap_fix/assets/minecraft/textures/colormap/grass.png" \
     "$WORKDIR/matcha_raw/assets/minecraft/textures/colormap/grass.png"
  cp "$WORKDIR/colourmap_fix/assets/minecraft/textures/colormap/foliage.png" \
     "$WORKDIR/matcha_raw/assets/minecraft/textures/colormap/foliage.png"
  echo "  applied colourmap fix (grass.png, foliage.png only)"
else
  echo "== Step 6: Skipped (no Matcha_Colourmap_Fix.zip present -- assuming already applied or not needed) =="
fi

# -----------------------------------------------------------------------------
# Step 7: Layer everything together. PRIORITY: Stellarity -> Sparkles -> Matcha
# (later copy wins on any overlapping file path)
# -----------------------------------------------------------------------------
echo "== Step 7: Layering all packs (Stellarity -> Sparkles -> Matcha priority) =="
FINAL="$WORKDIR/final"
mkdir -p "$FINAL"
cp -r "$WORKDIR/stellarity_resolved/assets" "$FINAL/"
cp -r "$WORKDIR/sparkles_resolved/assets" "$FINAL/"
cp -r "$WORKDIR/matcha_raw/assets" "$FINAL/"
if [ -d "$WORKDIR/matcha_raw/data" ]; then
  cp -r "$WORKDIR/matcha_raw/data" "$FINAL/"
fi
cp "$WORKDIR/matcha_raw/pack.mcmeta" "$FINAL/"
cp "$WORKDIR/matcha_raw/pack.png" "$FINAL/" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Step 8: Package and hash
# -----------------------------------------------------------------------------
echo "== Step 8: Packaging final zip =="
OUTPUT="Matcha_Stellarity_Incendium_combined.zip"
rm -f "$OUTPUT"
( cd "$FINAL" && zip -r -X "../../$OUTPUT" . -x ".*" > /dev/null )

SHA1=$(sha1sum "$OUTPUT" | awk '{print $1}')
echo "$SHA1" > "${OUTPUT}.sha1"

echo ""
echo "=============================================="
echo "DONE: $OUTPUT"
echo "SHA-1: $SHA1"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Copy $OUTPUT into your world's datapacks/ folder"
echo "  2. Upload $OUTPUT to your GitHub repo (replace the old file)"
echo "  3. Update server.properties:"
echo "       resource-pack=<your raw GitHub URL>"
echo "       resource-pack-sha1=$SHA1"
echo "  4. Fully restart the server (biome/water changes need a full restart, not /reload)"

# cleanup intermediate work
rm -rf "$WORKDIR"
