#!/bin/sh
set -eu
case "$PLATFORM_NAME" in
  iphoneos) source="$SRCROOT/Vendor/Azahar/azahar_libretro.dylib"; metal_slice=ios-arm64 ;;
  iphonesimulator) source="$SRCROOT/Vendor/Azahar/Simulator/azahar_libretro.dylib"; metal_slice=ios-arm64_x86_64-simulator ;;
  *) exit 0 ;;
esac
if [ ! -f "$source" ]; then
  echo "error: Missing Azahar core for $PLATFORM_NAME. See Scripts/build-simulator-core.sh."
  exit 1
fi
core="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/Azahar.framework"
mkdir -p "$core"
cp "$source" "$core/Azahar"
chmod u+w,ugo+x "$core/Azahar"
/usr/bin/install_name_tool -id '@rpath/Azahar.framework/Azahar' "$core/Azahar"
cp "$SRCROOT/Vendor/Azahar/Info.plist" "$core/Info.plist"
cp "$SRCROOT/Resources/Privacy/Azahar.xcprivacy" "$core/PrivacyInfo.xcprivacy"
metal="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/MoltenVK.framework"
metal_source="$SRCROOT/Vendor/MoltenVK/MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework/$metal_slice/MoltenVK.framework"
if [ "$PLATFORM_NAME" = iphoneos ]; then
  metal_source="$SRCROOT/Vendor/MoltenVK/Device/MoltenVK.framework"
fi
if [ ! -d "$metal_source" ]; then
  echo "error: Missing MoltenVK 1.4.2. See Scripts/prepare-moltenvk.py and Scripts/build-moltenvk-device.sh."
  exit 1
fi
rm -rf "$metal"
/usr/bin/ditto "$metal_source" "$metal"
rm -rf "$metal/Headers" "$metal/Modules"
cp "$SRCROOT/Resources/Privacy/MoltenVK.xcprivacy" "$metal/PrivacyInfo.xcprivacy"
# The app and this initial simulator core target arm64.
if [ "$PLATFORM_NAME" = iphonesimulator ]; then
  /usr/bin/lipo "$metal/MoltenVK" -thin arm64 -output "$metal/MoltenVK.arm64"
  mv "$metal/MoltenVK.arm64" "$metal/MoltenVK"
fi
cp "$SRCROOT/Vendor/MoltenVK/MoltenVK/LICENSE" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/MoltenVK-LICENSE.txt"
if [ "$ACTION" = install ] && [ "$PLATFORM_NAME" = iphoneos ]; then
  core_symbols="$SRCROOT/Vendor/Azahar/Azahar.framework.dSYM"
  metal_symbols="$SRCROOT/Vendor/MoltenVK/Device/MoltenVK.framework.dSYM"
  python3 "$SRCROOT/Scripts/check-debug-symbols.py" "$core/Azahar" "$core_symbols"
  python3 "$SRCROOT/Scripts/check-debug-symbols.py" "$metal/MoltenVK" "$metal_symbols"
  mkdir -p "$DWARF_DSYM_FOLDER_PATH"
  /usr/bin/ditto "$core_symbols" "$DWARF_DSYM_FOLDER_PATH/Azahar.framework.dSYM"
  /usr/bin/ditto "$metal_symbols" "$DWARF_DSYM_FOLDER_PATH/MoltenVK.framework.dSYM"
fi
if [ "$CODE_SIGNING_ALLOWED" = YES ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$metal"
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$core"
else
  /usr/bin/codesign --force --sign - --timestamp=none "$metal"
  /usr/bin/codesign --force --sign - --timestamp=none "$core"
fi
