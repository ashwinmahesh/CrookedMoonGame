#!/usr/bin/env bash
# Fetches the three CC0 bark scans of the Crooked Moon's tree plants from Poly Haven (https://polyhaven.com, CC0 1.0): the 2k diffuse,
# normal (OpenGL) and roughness JPEGs of bark_willow_02, bark_brown_02 and tree_bark_03, untouched, into art/sourced/polyhaven_<name>/.
# About 28 MB. Ashwin runs it himself (a download needs his own yes):
#   bash tools/art/fetch_bark_textures.sh
# The textures are then wired by art/plants/flora.json's `bark_texture` (engine Flora, bark.gdshader's `textured`), and each folder gets a
# SOURCE.md and LICENSE.txt and an entry in art/credits.json.
set -euo pipefail
cd "$(dirname "$0")/../.."
for name in bark_willow_02 bark_brown_02 tree_bark_03; do
  dir="art/sourced/polyhaven_${name}"
  mkdir -p "$dir"
  for map in diff nor_gl rough; do
    file="${name}_${map}_2k.jpg"
    if [ -s "$dir/$file" ]; then echo "have $dir/$file"; continue; fi
    curl -fL --retry 3 -o "$dir/$file" "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/${name}/${file}"
    echo "got  $dir/$file"
  done
done
