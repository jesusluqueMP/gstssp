#!/bin/bash

# Build script for gst-ssp plugin

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building GStreamer SSP Plugin${NC}"
echo "======================================"

# Check if meson is installed
if ! command -v meson &> /dev/null; then
    echo -e "${RED}Error: meson is not installed${NC}"
    echo "Please install meson: pip install meson"
    exit 1
fi

# Check if ninja is installed
if ! command -v ninja &> /dev/null; then
    echo -e "${RED}Error: ninja is not installed${NC}"
    echo "Please install ninja: brew install ninja (macOS) or apt install ninja-build (Ubuntu)"
    exit 1
fi

# Check for GStreamer development packages
if ! pkg-config --exists gstreamer-1.0; then
    echo -e "${RED}Error: GStreamer development packages not found${NC}"
    echo "Please install GStreamer development packages:"
    echo "  macOS: brew install gstreamer gst-plugins-base gst-plugins-good"
    echo "  Ubuntu: apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev"
    exit 1
fi

# Create build directory
BUILD_DIR="build"
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Removing existing build directory${NC}"
    rm -rf "$BUILD_DIR"
fi

echo -e "${GREEN}Setting up build directory${NC}"
meson setup "$BUILD_DIR"

echo -e "${GREEN}Building plugin${NC}"
meson compile -C "$BUILD_DIR"

echo -e "${GREEN}Build completed successfully!${NC}"
echo ""
echo "To install the plugin:"
echo "  sudo meson install -C $BUILD_DIR"
echo ""
echo "To test the plugin:"
echo "  export GST_PLUGIN_PATH=\$PWD/$BUILD_DIR/src"
echo "  gst-inspect-1.0 sspsrc"
