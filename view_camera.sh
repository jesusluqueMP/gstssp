#!/bin/bash

# Simple Z-Camera H.264 viewer script
# Usage: ./view_camera.sh [camera_ip]

CAMERA_IP=${1:-"192.168.1.34"}

echo "Starting Z-Camera viewer for IP: $CAMERA_IP"
echo "Press Ctrl+C to stop"

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

# Launch viewer with optimized pipeline
gst-launch-1.0 \
  sspsrc ip="$CAMERA_IP" mode=video ! \
  h264parse ! \
  queue max-size-buffers=10 ! \
  avdec_h264 ! \
  videoconvert ! \
  videoscale ! \
  video/x-raw,width=1280,height=720 ! \
  autovideosink sync=false
