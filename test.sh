#!/bin/bash

# Simple H.265 Camera Viewer
# Cross-platform test to view Z-Camera stream
# Usage: ./test.sh [uhd|1080p] [gop]

set -e  # Exit on errors

# Configuration
RESOLUTION=${1:-"1080p"}  # Default to HD 1080p for better performance, can be "uhd" or "1080p" 
GOP=${2:-1}               # Default GOP=1 (I-frame only)
CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================================"
echo "Simple H.265 Camera Viewer (10-bit 4:2:0)"
echo "Resolution: $(echo $RESOLUTION | tr '[:lower:]' '[:upper:]')"
echo "GOP: $GOP"
echo "========================================================"

# Check camera connectivity
print_info "Checking camera connectivity..."
if ! curl -s --connect-timeout 3 "http://$CAMERA_IP/info" > /dev/null; then
    print_error "Camera not reachable at $CAMERA_IP"
    exit 1
fi
print_info "Camera is reachable"

# Setup camera session
print_info "Taking camera session..."
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null

# Configure stream based on resolution
print_info "Configuring 10-bit 4:2:0 H.265 stream for $RESOLUTION..."

if [ "$RESOLUTION" = "uhd" ]; then
    # UHD (4K) configuration with 10-bit 4:2:0
    curl -s "http://$CAMERA_IP/ctrl/set?movfmt=4KP25" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=3840&height=2160&fps=25&venc=h265&bitwidth=10&qp=1&gop_n=$GOP&profile=main10&chroma=420" > /dev/null
else
    # HD 1080p configuration with 10-bit 4:2:0 
    curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h265&bitwidth=10&qp=1&gop_n=$GOP&profile=main10&chroma=420" > /dev/null
fi

curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null

# Activate streaming mode
print_info "Activating streaming..."
curl -s "http://$CAMERA_IP/ctrl/rec?action=start_no_record" > /dev/null

sleep 2

print_info "Starting 10-bit 4:2:0 H.265 viewer (Press Ctrl+C to stop)..."
print_info "Pipeline: sspsrc -> h265parse -> avdec_h265 -> autovideosink"

# Optimized H.265 pipeline for 10-bit 4:2:0 with minimal latency
gst-launch-1.0 -v \
    sspsrc ip="$CAMERA_IP" mode=video max-queue-size=1 latency-mode=true ! \
    queue max-size-buffers=1 max-size-time=0 max-size-bytes=0 ! \
    h265parse ! \
    avdec_h265 max-threads=1 ! \
    autovideosink sync=false

# Cleanup on exit
print_info "Cleaning up..."
curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null || true

print_info "Done!"
