#!/bin/bash

# Universal Z-Camera recording script with proper EOS handling
# Supports both H.264 and H.265 with MP4 output
# Usage: ./record_camera.sh [codec] [duration] [output_file] [camera_ip]

CODEC=${1:-"h264"}
DURATION=${2:-10}
OUTPUT_FILE=${3:-"recording_${CODEC}.mp4"}
CAMERA_IP=${4:-"192.168.1.34"}

echo "Z-Camera Recording Script"
echo "========================"
echo "Codec: $CODEC"
echo "Duration: ${DURATION} seconds"
echo "Output file: $OUTPUT_FILE"
echo "Camera IP: $CAMERA_IP"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

# Build pipeline based on codec
if [ "$CODEC" = "h265" ] || [ "$CODEC" = "hevc" ]; then
    echo "Configuring camera for H.265..."
    # Configure camera for H.265
    curl -s "http://$CAMERA_IP/ctrl/set?video_encoder=265" > /dev/null
    sleep 1
    
    PIPELINE="sspsrc ip=\"$CAMERA_IP\" mode=video ! h265parse ! video/x-h265,stream-format=hvc1 ! mp4mux ! filesink location=\"$OUTPUT_FILE\""
else
    echo "Configuring camera for H.264..."
    # Configure camera for H.264
    curl -s "http://$CAMERA_IP/ctrl/set?video_encoder=96" > /dev/null
    sleep 1
    
    PIPELINE="sspsrc ip=\"$CAMERA_IP\" mode=video ! h264parse ! video/x-h264,stream-format=avc ! mp4mux ! filesink location=\"$OUTPUT_FILE\""
fi

echo "Starting recording..."

# Start recording with proper EOS handling
gst-launch-1.0 $PIPELINE --eos-on-shutdown &

# Get the PID
GST_PID=$!

echo "Recording started (PID: $GST_PID)"
echo "Recording for ${DURATION} seconds..."

# Wait for specified duration
sleep $DURATION

# Send SIGINT for proper EOS
echo "Sending EOS signal for clean shutdown..."
kill -INT $GST_PID

# Wait for graceful shutdown
wait $GST_PID

echo ""
echo "Recording completed successfully!"
echo "File: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

echo ""
echo "File properties:"
ffprobe "$OUTPUT_FILE" 2>&1 | grep -E "(Duration|Video|bitrate)" | head -2
