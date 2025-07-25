#!/bin/bash

# Simple UHD/1080p H.265 Camera Viewer with Z-Log2
# Quick test to view Z-Camera stream with proper settings
# Usage: ./simple_h264_view.sh [uhd|1080p] [gop]

set -e  # Exit on errors

# Configuration
RESOLUTION=${1:-"uhd"}  # Default to UHD, can be "uhd" or "1080p"
GOP=${2:-1}             # Default GOP=1 (I-frame only), can be any number
CAMERA_IP="192.168.1.34"
LUT_FILE="$PWD/luts/Z-Log2/normal/zLog2_zRGB-ax2_64.cube"
export GST_PLUGIN_PATH="$PWD/build/src"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================================"
echo "Simple UHD/1080p H.265 Camera Viewer with Z-Log2"
echo "Resolution: $(echo $RESOLUTION | tr '[:lower:]' '[:upper:]')"
echo "GOP: $GOP"
echo "========================================================"

# Quick camera connectivity check
print_info "Checking camera connectivity..."
if ! curl -s --connect-timeout 3 "http://$CAMERA_IP/info" > /dev/null; then
    print_error "Camera not reachable at $CAMERA_IP"
    exit 1
fi
print_info "Camera is reachable"

# Check LUT file exists
if [ ! -f "$LUT_FILE" ]; then
    print_error "LUT file not found at $LUT_FILE"
    exit 1
fi
print_info "LUT file found: $(basename "$LUT_FILE")"

# Occupy session
print_info "Taking camera session..."
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null

# Quick H.265 configuration with Z-Log2 (resolution-dependent)
print_info "Configuring H.265 stream with Z-Log2 for $RESOLUTION..."
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null

if [ "$RESOLUTION" = "uhd" ]; then
    # UHD (4K) configuration
    curl -s "http://$CAMERA_IP/ctrl/set?movfmt=4KP25" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?lut=Z-Log2" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?movvfr=Off" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=3840&height=2160&fps=25&venc=h265&bitwidth=10&qp=1&gop_n=$GOP&profile=main10" > /dev/null
    WIDTH=3840
    HEIGHT=2160
    DISPLAY_WIDTH=1920
    DISPLAY_HEIGHT=1080
else
    # 1080p configuration
    curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?lut=Z-Log2" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?movvfr=Off" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h265&bitwidth=10&qp=1&gop_n=$GOP&profile=main10" > /dev/null
    WIDTH=1920
    HEIGHT=1080
    DISPLAY_WIDTH=1280
    DISPLAY_HEIGHT=720
fi

curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null

# Activate streaming mode
print_info "Activating streaming..."
curl -s "http://$CAMERA_IP/ctrl/rec?action=start_no_record" > /dev/null

sleep 2

print_info "Starting $RESOLUTION H.265 viewer with Z-Log2 LUT (Press Ctrl+C to stop)..."
print_info "Source: ${WIDTH}x${HEIGHT} -> Display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
print_info "Pipeline: sspsrc -> h265parse -> avdec_h265 -> OCIO LUT -> videosink"

# H.265 pipeline with OCIO LUT conversion (resolution adaptive)
gst-launch-1.0 -v \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    queue ! \
    h265parse ! \
    avdec_h265 ! \
    videoconvert ! \
    video/x-raw,format=RGB ! \
    ocio lut-file="$LUT_FILE" use-gpu=true ! \
    videoconvert ! \
    videoscale ! \
    video/x-raw,width=$DISPLAY_WIDTH,height=$DISPLAY_HEIGHT ! \
    autovideosink sync=false

# Cleanup on exit
print_info "Cleaning up..."
curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null || true

print_info "Done!"
