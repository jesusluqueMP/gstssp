#!/bin/bash

# Buffered H.264 Stream Test
# Uses larger buffers and longer timeouts to maintain SSP connection

set -e

CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

echo "Testing H.264 SSP stream with better buffering..."

# Session setup
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=5000000&gop_n=25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null

# Try starting recording to keep stream active
curl -s "http://$CAMERA_IP/ctrl/rec?action=start" > /dev/null
sleep 1

echo "Starting buffered H.264 viewer..."

# Enhanced pipeline with larger buffers and better error handling
gst-launch-1.0 -v \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    queue max-size-buffers=100 max-size-time=5000000000 max-size-bytes=0 leaky=downstream ! \
    h264parse ! \
    queue max-size-buffers=50 max-size-time=2000000000 max-size-bytes=0 ! \
    avdec_h264 ! \
    videoconvert ! \
    queue max-size-buffers=10 ! \
    glimagesink sync=false async=false

# Cleanup
curl -s "http://$CAMERA_IP/ctrl/rec?action=stop" > /dev/null || true
curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null || true
echo "Test completed."
