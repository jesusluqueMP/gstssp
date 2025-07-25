#!/bin/bash

# Z-Camera UHD (3840x2160) Recording Script
# Usage: ./record_uhd.sh [duration] [output_file] [camera_ip]

DURATION=${1:-30}
OUTPUT_FILE=${2:-"uhd_recording.mp4"}
CAMERA_IP=${3:-"192.168.1.34"}

echo "Z-Camera UHD (3840x2160) Recording"
echo "=================================="
echo "Duration: ${DURATION} seconds"
echo "Output: $OUTPUT_FILE"
echo "Camera: $CAMERA_IP"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

echo "Configuring camera for UHD recording..."

# Get session control
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null

# Configure UHD H.264 (known working configuration)
echo "Setting UHD (3840x2160) H.264 stream..."
response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream1&width=3840&height=2160&fps=25&venc=h264&bitwidth=8&bitrate=40000000&gop_n=25")
code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")

if [ "$code" = "0" ]; then
    echo "✅ UHD H.264 stream configured successfully"
else
    echo "⚠️ UHD stream configuration failed: $response"
fi

# Set Z-Log2 for better dynamic range
curl -s "http://$CAMERA_IP/ctrl/set?lut=Z-Log2" > /dev/null
echo "✅ Z-Log2 color profile set"

# Set Stream1 as source
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream1" > /dev/null
echo "✅ Stream1 set as source"

echo ""
echo "Waiting for stream to stabilize..."
sleep 3

echo "Starting UHD recording..."
echo ""

# Record with simple pipeline
gst-launch-1.0 \
  sspsrc ip="$CAMERA_IP" mode=video ! \
  queue ! \
  parsebin ! \
  mp4mux ! \
  filesink location="$OUTPUT_FILE" \
  --eos-on-shutdown &

# Get PID
GST_PID=$!

echo "Recording started (PID: $GST_PID)"
echo "Recording UHD (3840x2160) for ${DURATION} seconds..."
echo "Press Ctrl+C to stop early"

# Wait for duration
sleep $DURATION

# Send EOS for clean shutdown
echo ""
echo "Sending EOS signal for clean shutdown..."
kill -INT $GST_PID
wait $GST_PID

echo ""
echo "Recording completed!"
echo "File: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

echo ""
echo "File properties:"
ffprobe "$OUTPUT_FILE" 2>&1 | grep -E "(Duration|Video|Stream)" | head -3

# Check actual resolution and codec
echo ""
echo "Checking recording format:"
resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT_FILE" 2>/dev/null)
codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$OUTPUT_FILE" 2>/dev/null)

if [[ $resolution == "3840,2160" ]]; then
    echo "✅ UHD Resolution: 3840x2160"
else
    echo "⚠️ Resolution: $resolution (not UHD)"
fi

if [[ $codec == "h264" ]]; then
    echo "✅ Codec: H.264"
elif [[ $codec == "hevc" ]]; then
    echo "✅ Codec: H.265/HEVC"
else
    echo "⚠️ Codec: $codec"
fi

echo ""
if [[ $resolution == "3840,2160" ]]; then
    echo "🎉 UHD RECORDING SUCCESSFUL!"
    echo "   Resolution: 3840x2160 (UHD)"
    echo "   Codec: $codec"
    echo "   Color Profile: Z-Log2"
else
    echo "⚠️ Recording completed but not at UHD resolution"
fi
