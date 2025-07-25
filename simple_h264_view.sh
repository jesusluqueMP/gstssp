#!/bin/bash

# Simple H.264 Camera Viewer
# Quick test to view Z-Camera H.264 stream in GL window

set -e  # Exit on errors

# Configuration
CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================================"
echo "Simple H.264 Camera Viewer"
echo "========================================================"

# Quick camera connectivity check
print_info "Checking camera connectivity..."
if ! curl -s --connect-timeout 3 "http://$CAMERA_IP/info" > /dev/null; then
    print_error "Camera not reachable at $CAMERA_IP"
    exit 1
fi
print_info "Camera is reachable"

# Occupy session
print_info "Taking camera session..."
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null

# Quick H.264 configuration
print_info "Configuring H.264 stream..."
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=10000000&gop_n=25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null

# Activate streaming mode
print_info "Activating streaming..."
curl -s "http://$CAMERA_IP/ctrl/rec?action=start_no_record" > /dev/null

sleep 2

print_info "Starting H.264 viewer (Press Ctrl+C to stop)..."
print_info "Pipeline: sspsrc -> h264parse -> avdec_h264 -> videosink"

# Try different video sinks for better compatibility
gst-launch-1.0 -v \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h264parse ! \
    avdec_h264 ! \
    videoconvert ! \
    videoscale ! \
    video/x-raw,width=1280,height=720 ! \
    autovideosink sync=false

# Cleanup on exit
print_info "Cleaning up..."
curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null || true

print_info "Done!"
