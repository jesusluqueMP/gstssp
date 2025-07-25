#!/bin/bash

# Minimal H.264 Stream Test with Connection Keep-Alive
# Tests various approaches to maintain SSP connection

set -e

CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

echo "Testing H.264 SSP stream with different approaches..."

# Session setup
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=8000000&gop_n=25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null

echo "Approach 1: Try with fakesink first to establish connection..."
timeout 10s gst-launch-1.0 -v sspsrc ip="$CAMERA_IP" mode=video ! fakesink &
FAKESINK_PID=$!
sleep 3

echo "Approach 2: Start viewer pipeline while fakesink is running..."
gst-launch-1.0 -v \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h264parse ! \
    queue ! \
    avdec_h264 ! \
    videoconvert ! \
    glimagesink sync=false &

VIEWER_PID=$!

echo "Letting both run for 30 seconds..."
sleep 30

# Clean up
kill $FAKESINK_PID 2>/dev/null || true
kill $VIEWER_PID 2>/dev/null || true
wait $FAKESINK_PID 2>/dev/null || true
wait $VIEWER_PID 2>/dev/null || true

curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null || true
echo "Test completed."
