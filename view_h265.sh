#!/bin/bash

# Z-Camera H.265 viewer and recorder script
# Usage: ./view_h265.sh [camera_ip] [record|view]

CAMERA_IP=${1:-"192.168.1.34"}
MODE=${2:-"view"}

echo "Starting Z-Camera H.265 $MODE for IP: $CAMERA_IP"
echo "Press Ctrl+C to stop"

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

if [ "$MODE" = "record" ]; then
  echo "Recording H.265 to h265_recording.mkv (Matroska format - better H.265 support)"
  gst-launch-1.0 \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h265parse ! \
    queue max-size-buffers=30 ! \
    matroskamux ! \
    filesink location=h265_recording.mkv
else
  echo "Viewing H.265 live stream"
  gst-launch-1.0 \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h265parse ! \
    queue max-size-buffers=10 ! \
    avdec_h265 ! \
    videoconvert ! \
    videoscale ! \
    video/x-raw,width=1280,height=720 ! \
    autovideosink sync=false
fi
