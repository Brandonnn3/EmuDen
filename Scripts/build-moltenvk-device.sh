#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
root="$PWD"
source_dir="$root/Vendor/MoltenVK/Source"
commit=db66022459ffb663aa2b50f6b018bc2e124f5edf
if [ ! -d "$source_dir/.git" ]; then
  git clone --depth 1 --branch v1.4.2 https://github.com/KhronosGroup/MoltenVK.git "$source_dir"
fi
if [ "$(git -C "$source_dir" rev-parse HEAD)" != "$commit" ]; then
  echo "error: MoltenVK source is not the pinned 1.4.2 commit."
  exit 1
fi
cd "$source_dir"
./fetchDependencies --none
xcodebuild build -project ExternalDependencies.xcodeproj -scheme ExternalDependencies-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$root/build/MoltenVKDependencies" -jobs 2 \
  DEBUG_INFORMATION_FORMAT=dwarf-with-dsym GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
  IPHONEOS_DEPLOYMENT_TARGET=18.0 CODE_SIGNING_ALLOWED=NO
xcodebuild build -project MoltenVK/MoltenVK.xcodeproj -scheme MoltenVK-iOS-dynamic \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$root/build/MoltenVKDevice" -jobs 2 \
  DEBUG_INFORMATION_FORMAT=dwarf-with-dsym GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) MVK_USE_METAL_PRIVATE_API=0' \
  IPHONEOS_DEPLOYMENT_TARGET=18.0 CODE_SIGNING_ALLOWED=NO
cd "$root"
product=build/MoltenVKDevice/Build/Products/Release-iphoneos
python3 Scripts/check-debug-symbols.py "$product/MoltenVK.framework/MoltenVK" "$product/MoltenVK.framework.dSYM"
mkdir -p Vendor/MoltenVK/Device
/usr/bin/ditto "$product/MoltenVK.framework" Vendor/MoltenVK/Device/MoltenVK.framework
/usr/bin/ditto "$product/MoltenVK.framework.dSYM" Vendor/MoltenVK/Device/MoltenVK.framework.dSYM
