#!/usr/bin/env bash
# Rebuild both debug APKs. Needs Godot 4.7.2 with Android export templates,
# Java, apksigner (an Android SDK folder with build-tools/<ver>/apksigner),
# and a debug keystore set in Godot's editor settings.
set -euo pipefail
GODOT=${GODOT:-godot}
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$HERE/../builds}
mkdir -p "$OUT"
python3 "$HERE/tools/make_assets.py"
"$GODOT" --headless --path "$HERE" --import
"$GODOT" --headless --path "$HERE" --export-debug Android "$OUT/collapse-device-test-opengl.apk"
# Vulkan variant: same project, Mobile renderer, different package name.
VK=$(mktemp -d)
cp -r "$HERE/." "$VK/"
sed -i 's/rendering_method="gl_compatibility"/rendering_method="mobile"/; s/rendering_method.mobile="gl_compatibility"/rendering_method.mobile="mobile"/; s/"GL Compatibility"/"Mobile"/' "$VK/project.godot"
sed -i 's/devicetest.gl"/devicetest.vk"/; s/Collapse Test GL/Collapse Test Vulkan/' "$VK/export_presets.cfg"
"$GODOT" --headless --path "$VK" --import
"$GODOT" --headless --path "$VK" --export-debug Android "$OUT/collapse-device-test-vulkan.apk"
echo "APKs in $OUT"
