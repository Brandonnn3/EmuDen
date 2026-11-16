#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
case "${1:-simulator}" in
  simulator) sdk=iphonesimulator; build_dir=build/AzaharSimulator; destination=Vendor/Azahar/Simulator ;;
  device) sdk=iphoneos; build_dir=build/AzaharDevice; destination=Vendor/Azahar ;;
  *) echo "Usage: $0 [simulator|device]"; exit 2 ;;
esac
build_dir="${CORE_BUILD_DIR:-$build_dir}"
case "$sdk" in
  iphoneos) tls_slice=Device ;;
  iphonesimulator) tls_slice=Simulator ;;
esac
tls="$PWD/Vendor/OpenSSL/$tls_slice"
if [ ! -f "$tls/lib/libssl.a" ] || [ ! -f "$tls/lib/libcrypto.a" ]; then
  echo "Build the Apache-2.0 TLS dependency with Scripts/build-openssl.py first."
  exit 1
fi
# Requires the checksum-verified 2127.0-rc1 unified source in Vendor/Azahar/Source.
# CMake and Ninja are installed locally in .tools; no global toolchain is modified.
python3 Scripts/patch-azahar.py
python3 Scripts/prepare-mii-fallback.py
source_dir="$(python3 -c 'from pathlib import Path; print(Path("Vendor/Azahar/Source").resolve())')"
.tools/bin/cmake -S "$source_dir" -B "$build_dir" -G Ninja \
  -DCMAKE_MAKE_PROGRAM="$PWD/.tools/bin/ninja" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG -gline-tables-only" \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG -gline-tables-only" \
  -DCMAKE_OBJCXX_FLAGS_RELEASE="-O3 -DNDEBUG -gline-tables-only" \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=18.0 \
  -DENABLE_LIBRETRO=ON -DENABLE_TESTS=OFF -DENABLE_QT=OFF -DENABLE_SDL2=OFF \
  -DUSE_SYSTEM_OPENSSL=ON -DOPENSSL_USE_STATIC_LIBS=ON \
  -DOPENSSL_INCLUDE_DIR="$tls/include" -DOPENSSL_SSL_LIBRARY="$tls/lib/libssl.a" \
  -DOPENSSL_CRYPTO_LIBRARY="$tls/lib/libcrypto.a" \
  -DENABLE_WEB_SERVICE=OFF -DENABLE_SCRIPTING=OFF -DENABLE_ROOM=OFF -DENABLE_BUILTIN_KEYBLOB=OFF \
  -DENABLE_GDBSTUB=OFF -DENABLE_CUBEB=OFF -DENABLE_OPENAL=OFF -DENABLE_LIBUSB=OFF \
  -DENABLE_VULKAN=ON -DENABLE_OPENGL=OFF -DENABLE_SOFTWARE_RENDERER=ON \
  -DENABLE_LTO=OFF -DCITRA_USE_PRECOMPILED_HEADERS="${CORE_PCH:-OFF}" -DCITRA_WARNINGS_AS_ERRORS=OFF
.tools/bin/cmake --build "$build_dir" --target citra_libretro --parallel "${CORE_JOBS:-2}"
mkdir -p "$destination"
cp "$build_dir/bin/Release/azahar_libretro.dylib" "$destination/azahar_libretro.dylib"
symbols="$destination/.Azahar.framework.dSYM.tmp"
rm -rf "$symbols"
xcrun dsymutil "$destination/azahar_libretro.dylib" -o "$symbols"
mv "$symbols/Contents/Resources/DWARF/azahar_libretro.dylib" "$symbols/Contents/Resources/DWARF/Azahar"
python3 Scripts/check-debug-symbols.py "$destination/azahar_libretro.dylib" "$symbols"
rm -rf "$destination/Azahar.framework.dSYM"
mv "$symbols" "$destination/Azahar.framework.dSYM"
