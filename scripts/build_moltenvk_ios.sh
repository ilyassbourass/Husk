#!/bin/bash
# Build MoltenVK for iOS (arm64) and stage it where the app project expects it.
#
# Unreal Engine 4 games (Minecraft Dungeons) draw with Vulkan, and on Apple hardware Vulkan is MoltenVK. The Mac one from Homebrew is no use on a phone, so this
# builds KhronosGroup/MoltenVK from source: `fetchDependencies --ios` clones and builds SPIRV-Cross and SPIRV-Tools, `make ios` produces a dynamic MoltenVK.framework
# in an xcframework. project.yml embeds build/ios-arm64/lib/MoltenVK.xcframework; the native runtime opens it by path (husk_ue4_set_vulkan).
set -euo pipefail

HUSK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${MOLTENVK_VERSION:-v1.4.2}"
SRC="$HUSK_ROOT/third_party/build/MoltenVK-${VERSION#v}"
OUT="$HUSK_ROOT/build/ios-arm64/lib"

mkdir -p "$OUT"
if [ -d "$OUT/MoltenVK.xcframework" ]; then
    echo "==> MoltenVK.xcframework already present at $OUT/MoltenVK.xcframework"
    exit 0
fi

MVK_TAR="/tmp/MoltenVK-ios.tar"
MVK_TMP="/tmp/mvk_extract"
echo "==> fetching official prebuilt MoltenVK $VERSION for iOS"
if curl -fL --retry 3 -o "$MVK_TAR" "https://github.com/KhronosGroup/MoltenVK/releases/download/$VERSION/MoltenVK-ios.tar" 2>/dev/null; then
    rm -rf "$MVK_TMP"
    mkdir -p "$MVK_TMP"
    tar -xf "$MVK_TAR" -C "$MVK_TMP"
    rm -rf "$OUT/MoltenVK.xcframework"
    cp -R "$MVK_TMP/MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework" "$OUT/"
    rm -rf "$MVK_TAR" "$MVK_TMP"
    echo "==> staged $OUT/MoltenVK.xcframework"
    exit 0
fi

echo "==> prebuilt download unavailable; building MoltenVK from source"
if [ ! -d "$SRC" ]; then
    echo "==> cloning MoltenVK $VERSION"
    git clone --depth 1 --branch "$VERSION" https://github.com/KhronosGroup/MoltenVK "$SRC"
fi
cd "$SRC"
[ -d External/build/Release/SPIRVCross.xcframework ] || { echo "==> fetching dependencies"; ./fetchDependencies --ios; }
echo "==> building"
make ios
rm -rf "$OUT/MoltenVK.xcframework"
cp -R Package/Release/MoltenVK/dynamic/MoltenVK.xcframework "$OUT/"
echo "==> $OUT/MoltenVK.xcframework"
