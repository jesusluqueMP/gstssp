#!/bin/bash

# Simple H.264 Viewer with Recording Activation
# Tests if starting recording maintains SSP stream

CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

echo "Testing H.264 viewer with recording activation..."

# Setup camera
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=8000000&gop_n=25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null

echo "Starting recording to activate stream..."
curl -s "http://$CAMERA_IP/ctrl/rec?action=start" > /dev/null

sleep 2

echo "Starting H.264 viewer while recording..."
gst-launch-1.0 -v \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h264parse ! \
    avdec_h264 ! \
    videoconvert ! \
    glimagesink sync=false &

VIEWER_PID=$!

echo "Viewer running... Press Enter to stop recording and continue viewing"
read

echo "Stopping recording but keeping viewer..."
curl -s "http://$CAMERA_IP/ctrl/rec?action=stop" > /dev/null

echo "Viewer still running without recording... Press Enter to stop"
read

echo "Stopping viewer..."
kill $VIEWER_PID 2>/dev/null || true
wait $VIEWER_PID 2>/dev/null || true

curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null || true
echo "Test completed."
