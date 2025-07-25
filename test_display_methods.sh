#!/bin/bash

# Debug H.264 Viewer - Tests different display methods
# The plugin is working - let's fix the display

CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

echo "========================================================"
echo "Testing H.264 Display Methods"
echo "========================================================"

# Setup camera
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/mode?action=to_rec" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?movfmt=1080P25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=10000000&gop_n=25" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null
curl -s "http://$CAMERA_IP/ctrl/rec?action=start_no_record" > /dev/null

echo "Plugin is working! Testing display methods..."

echo "Method 1: Simple display (should show video window)"
timeout 10s gst-launch-1.0 \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h264parse ! \
    avdec_h264 ! \
    autovideosink

echo ""
echo "Method 2: Forced video output"
timeout 10s gst-launch-1.0 \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h264parse ! \
    avdec_h264 ! \
    videoconvert ! \
    osxvideosink

echo ""
echo "Method 3: Save to file (this should definitely work)"
gst-launch-1.0 -e \
    sspsrc ip="$CAMERA_IP" mode=video ! \
    h264parse ! \
    mp4mux ! \
    filesink location=test_capture.mp4 &

PID=$!
echo "Recording for 10 seconds..."
sleep 10
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo "Check test_capture.mp4 file - it should contain video!"
ls -la test_capture.mp4 2>/dev/null || echo "File not created"

curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null
echo "Done!"
