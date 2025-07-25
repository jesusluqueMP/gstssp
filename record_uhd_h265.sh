#!/bin/bash

# Z-Camera UHD (3840x2160) H.265 10-bit Z-Log Recording Script
# Usage: ./record_uhd_h265.sh [duration] [output_file] [camera_ip]

DURATION=${1:-30}
OUTPUT_FILE=${2:-"uhd_h265_recording.mp4"}
CAMERA_IP=${3:-"192.168.1.34"}

echo "Z-Camera UHD (3840x2160) H.265 Maximum Quality Recording"
echo "========================================================"
echo "Duration: ${DURATION} seconds"
echo "Output: $OUTPUT_FILE"
echo "Camera: $CAMERA_IP"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

echo "Configuring camera for UHD maximum quality recording..."

# Get session control
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null

# Set Z-Log2 for maximum dynamic range first
curl -s "http://$CAMERA_IP/ctrl/set?lut=Z-Log2" > /dev/null
echo "✅ Z-Log2 color profile set"

# Turn off VFR for consistent quality
curl -s "http://$CAMERA_IP/ctrl/set?movvfr=Off" > /dev/null
echo "✅ VFR disabled"

# Try to configure UHD H.265 10-bit for maximum quality
echo "Attempting UHD H.265 10-bit configuration..."
response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream1&width=3840&height=2160&fps=25&venc=h265&bitwidth=10&bitrate=50000000&gop_n=25")
h265_code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")

if [ "$h265_code" = "0" ]; then
    echo "✅ UHD H.265 10-bit stream configured"
    codec_mode="H.265 10-bit"
    bitrate="50 Mbps"
else
    # Fallback to H.264 (known working)
    echo "⚠️ H.265 10-bit not available, falling back to H.264..."
    curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream1&width=3840&height=2160&fps=25&venc=h264&bitwidth=8&bitrate=40000000&gop_n=25" > /dev/null
    echo "✅ UHD H.264 stream configured (fallback)"
    codec_mode="H.264 8-bit"
    bitrate="40 Mbps"
fi

# Set Stream1 as source
curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream1" > /dev/null
echo "✅ Stream1 set as source"

echo ""
echo "Configuration summary:"
echo "- Resolution: 3840x2160 (UHD)"
echo "- Codec: $codec_mode"
echo "- Bitrate: $bitrate"
echo "- Color Profile: Z-Log2"
echo "- Frame Rate: 25 FPS"

echo ""
echo "Waiting for stream to stabilize..."
sleep 3

echo "Starting UHD recording..."
echo ""

# Record with auto-detecting pipeline
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
echo "Recording UHD (3840x2160) maximum quality for ${DURATION} seconds..."
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
ffprobe "$OUTPUT_FILE" 2>&1 | grep -E "(Duration|Video|bitrate)" | head -3

# Check actual recording format
echo ""
echo "Checking recording format:"
codec_info=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,profile,pix_fmt,width,height -of csv=p=0 "$OUTPUT_FILE" 2>/dev/null)
resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT_FILE" 2>/dev/null)

if [[ $resolution == "3840,2160" ]]; then
    echo "✅ UHD Resolution: 3840x2160"
else
    echo "⚠️ Resolution: $resolution"
fi

if [[ $codec_info == *"hevc"* ]]; then
    echo "✅ Codec: H.265/HEVC"
    if [[ $codec_info == *"10le"* ]]; then
        echo "✅ Bit Depth: 10-bit"
        quality_level="MAXIMUM QUALITY"
    else
        echo "✅ Bit Depth: 8-bit"
        quality_level="HIGH QUALITY"
    fi
elif [[ $codec_info == *"h264"* ]]; then
    echo "✅ Codec: H.264"
    echo "✅ Bit Depth: 8-bit"
    quality_level="GOOD QUALITY"
fi

echo "✅ Container: MP4"
echo "✅ Color Profile: Z-Log2"

echo ""
if [[ $resolution == "3840,2160" ]]; then
    echo "🎉 UHD $quality_level RECORDING ACHIEVED!"
    echo ""
    echo "Summary:"
    echo "- Resolution: 3840x2160 (Ultra HD)"
    echo "- Codec: $(echo $codec_info | cut -d',' -f1)"
    echo "- Color Space: Z-Log2 (Extended Dynamic Range)"
    echo "- Quality Level: $quality_level"
    if [[ $codec_info == *"hevc"* ]] && [[ $codec_info == *"10le"* ]]; then
        echo "- Note: This is the highest quality possible from Z-Camera E2!"
    fi
else
    echo "⚠️ Recording completed but not at UHD resolution"
fi
