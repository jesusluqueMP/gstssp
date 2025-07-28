#!/bin/bash
set -e

if [ -d "build" ]; then
    rm -rf build
fi

if [ -d "install" ]; then
    rm -rf install
fi

meson setup build
meson compile -C build

echo "Build completed successfully!"
echo ""
echo "=== Plugin Version 3.0.0 Built Successfully ==="
echo ""
echo "To use the plugin, run these commands:"
echo "export GST_PLUGIN_PATH=\"\$PWD/build/src\""
echo "export DYLD_LIBRARY_PATH=\"\$PWD/libssp/lib/mac_arm64:\$DYLD_LIBRARY_PATH\""
echo ""
echo "Then you can:"
echo "  gst-inspect-1.0 sspsrc     # Inspect the plugin"
echo "  ./test.sh                  # Run the camera test"
echo ""
echo "Or run this one-liner to test immediately:"
echo "GST_PLUGIN_PATH=\"\$PWD/build/src\" DYLD_LIBRARY_PATH=\"\$PWD/libssp/lib/mac_arm64:\$DYLD_LIBRARY_PATH\" gst-inspect-1.0 sspsrc" install -C build

