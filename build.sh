#!/bin/bash
# build.sh device  -> build/HNReader.ipa (armv7, iOS 6, unsigned; install with ideviceinstaller on an AppSync device)
# build.sh sim     -> build/sim/HNReader.app (arm64 simulator, for previewing the layout with live data)
# SDK93 must point at an iOS 9.3 SDK (stub frameworks are enough, we link with -undefined dynamic_lookup).
set -e
cd "$(dirname "$0")"
SRC=(src/*.m)
if [ "$1" = device ]; then
    : "${SDK93:?set SDK93 to the iOS 9.3 SDK path}"
    rm -rf build/device; mkdir -p build/device/Payload/HNReader.app
    # compile with ARC but link without it: the Xcode toolchain has no libarclite, and iOS 6's libobjc already has the ARC entry points we use
    OBJS=()
    CFLAGS=(-DMBEDTLS_CONFIG_FILE='"hn_mbedtls_config.h"' -Ithird_party -Ithird_party/mbedtls/include -Ithird_party/mbedtls/library -Isrc)
    for f in third_party/mbedtls/library/*.c src/*.c; do
        o=build/device/$(basename "$f" .c).o
        xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" -Os -w "${CFLAGS[@]}" -c "$f" -o "$o"
        OBJS+=("$o")
    done
    for f in "${SRC[@]}"; do
        o=build/device/$(basename "$f" .m).o
        xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" -fobjc-arc -Os -Wno-deprecated-declarations -Isrc -c "$f" -o "$o"
        OBJS+=("$o")
    done
    xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" \
        -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -undefined dynamic_lookup \
        "${OBJS[@]}" -o build/device/Payload/HNReader.app/HNReader
    cp Info.plist res/*.png res/cacert.pem build/device/Payload/HNReader.app/
    (cd build/device && zip -q -r ../HNReader.ipa Payload)
    echo "built build/HNReader.ipa"
else
    SIM=$(xcrun --sdk iphonesimulator --show-sdk-path)
    rm -rf build/sim; mkdir -p build/sim/HNReader.app
    xcrun clang -arch arm64 -mios-simulator-version-min=15.0 -isysroot "$SIM" -fobjc-arc -O0 -DHN_PREVIEW -Wno-deprecated-declarations \
        -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
        -DMBEDTLS_CONFIG_FILE='"hn_mbedtls_config.h"' -Ithird_party -Ithird_party/mbedtls/include -Ithird_party/mbedtls/library -Isrc -w \
        "${SRC[@]}" third_party/mbedtls/library/*.c src/*.c -o build/sim/HNReader.app/HNReader
    cp Info.plist res/*.png res/cacert.pem build/sim/HNReader.app/
    # let the simulator build talk plain HTTP to localhost (tools/mock_hn.py); the device build keeps the stock Info.plist
    /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" build/sim/HNReader.app/Info.plist
    echo "built build/sim/HNReader.app"
fi
