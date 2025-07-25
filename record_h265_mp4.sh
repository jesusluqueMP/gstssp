#!/bin/bash

# Z-Camera H.265 MP4 recording script with proper EOS handling
# Usage: ./record_h265_mp4.sh [duration_seconds] [output_file] [camera_ip]

DURATION=${1:-10}
OUTPUT_FILE=${2:-"h265_recording.mp4"}
CAMERA_IP=${3:-"192.168.1.34"}

echo "Recording H.265 from Z-Camera for ${DURATION} seconds..."
echo "Camera IP: $CAMERA_IP"
echo "Output file: $OUTPUT_FILE"

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

# Start recording in background with proper EOS handling
gst-launch-1.0 \
  sspsrc ip="$CAMERA_IP" mode=video ! \
  h265parse ! \
  video/x-h265,stream-format=hvc1 ! \
  mp4mux ! \
  filesink location="$OUTPUT_FILE" \
  --eos-on-shutdown &

# Get the PID of gst-launch
GST_PID=$!

echo "Recording started (PID: $GST_PID)..."
echo "Recording for ${DURATION} seconds, then sending proper EOS..."

# Wait for specified duration
sleep $DURATION

# Send SIGINT for proper EOS and cleanup
echo "Sending EOS signal..."
kill -INT $GST_PID

# Wait for process to finish gracefully
wait $GST_PID

echo "Recording completed: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

# Show file info
echo ""
echo "File properties:"
ffprobe "$OUTPUT_FILE" 2>&1 | grep -E "(Duration|Video|bitrate)"
