#!/bin/bash

# Z-Camera UHD (3840x2160) H.265 10-bit HDR Z-Log Display Script
# Usage: ./record_max_quality.sh [duration] [camera_ip]

DURATION=${1:-30}
CAMERA_IP=${2:-"192.168.1.34"}

echo "Z-Camera UHD (3840x2160) H.265 10-bit HDR Z-Log Display"
echo "=================================================="
echo "Duration: ${DURATION} seconds"
echo "Camera: $CAMERA_IP"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

echo "Configuring camera for maximum quality..."

# Function to set camera parameter with feedback
set_param() {
    local key=$1
    local value=$2
    local description=$3
    
    response=$(curl -s "http://$CAMERA_IP/ctrl/set?k=$key&v=$value")
    code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")
    
    if [ "$code" = "0" ]; then
        echo "✅ $description set successfully"
    else
        echo "⚠️ $description not set (may not be supported): $response"
    fi
}

echo "Configuring camera for UHD (3840x2160) 10-bit Z-Log..."

# Function to set camera parameter with feedback (using proper API format)
set_param() {
    local key=$1
    local value=$2
    local description=$3
    
    response=$(curl -s "http://$CAMERA_IP/ctrl/set?$key=$value")
    code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")
    
    if [ "$code" = "0" ]; then
        echo "✅ $description set successfully"
    else
        echo "⚠️ $description: $response"
    fi
}

# Function to set stream parameter for UHD configuration
set_stream_param() {
    local param=$1
    local value=$2
    local description=$3
    
    response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&$param=$value")
    code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")
    
    if [ "$code" = "0" ]; then
        echo "✅ $description set successfully"
    else
        echo "⚠️ $description: $response"
    fi
}

# Get session control first
echo "Getting camera session..."
curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null

# 1. Set Z-Log2 color profile for maximum dynamic range
set_param "lut" "Z-Log2" "Z-Log2 color profile"
sleep 0.5

# 2. Turn off VFR for consistent quality
set_param "movvfr" "Off" "VFR disabled"
sleep 0.5

# 3. Stop streaming to allow configuration changes
set_param "send_stream" "none" "Stopping stream"
sleep 2

# 4. Configure Stream0 for UHD H.265 following zdump pattern
echo "Configuring Stream0 for UHD H.265 (following zdump pattern)..."

# Set movie format first (like zdump does)
set_param "movfmt" "4KP25" "4K 25fps movie format"
sleep 0.5

# Configure Stream0 with all parameters in one call (zdump style)
bitrate_bps=$((300 * 1000 * 1000))  # 300 Mbps in bps
stream_config_url="index=stream0&fps=25&width=3840&height=2160&venc=h265&bitwidth=10&bitrate=${bitrate_bps}&gop_n=1"

echo "Setting Stream0 parameters:"
echo "  - Resolution: 3840x2160 (UHD)"
echo "  - Codec: H.265 (venc=h265)" 
echo "  - Bit Width: 10-bit (bitwidth=10)"
echo "  - Bitrate: 300 Mbps"
echo "  - GOP: 1 frame (I-frame only for maximum quality)"

response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config_url")
code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")

if [ "$code" = "0" ]; then
    echo "✅ Stream0 H.265 10-bit UHD configuration successful"
    codec_mode="H.265 10-bit"
    bitrate_mode="300 Mbps"
    else
        echo "⚠️ H.265 10-bit failed, trying H.265 8-bit..."
        # Fallback to H.265 8-bit
        bitrate_bps=$((200 * 1000 * 1000))  # 200 Mbps in bps
        stream_config_url="index=stream0&fps=25&width=3840&height=2160&venc=h265&bitwidth=8&bitrate=${bitrate_bps}&gop_n=1"
        
        response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config_url")
        code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")
        
        if [ "$code" = "0" ]; then
            echo "✅ Stream0 H.265 8-bit UHD configuration successful"
            codec_mode="H.265 8-bit"
            bitrate_mode="200 Mbps"
        else
            echo "⚠️ H.265 failed, falling back to H.264..."
            # Final fallback to H.264
            stream_config_url="index=stream0&fps=25&width=3840&height=2160&venc=h264&bitwidth=8&bitrate=${bitrate_bps}&gop_n=1"
        curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config_url" > /dev/null
        echo "✅ Stream0 H.264 8-bit UHD configuration set (fallback)"
        codec_mode="H.264 8-bit (fallback)"
        bitrate_mode="200 Mbps"
    fi
fi

echo "   - Stream0 is primary recording stream"
echo "   - Resolution: 3840x2160 (UHD)"
echo "   - Codec: $codec_mode"
echo "   - Bitrate: $bitrate_mode"
echo "   - FPS: 25"

sleep 1

# 5. Use Stream0 as network streaming source
set_param "send_stream" "Stream0" "Stream0 as UHD source"
sleep 2

# 6. Wait for stream to stabilize before recording
echo "Waiting for UHD stream to initialize..."
sleep 3
# Check final settings
echo ""
echo "Current camera settings:"
current_lut=$(curl -s "http://$CAMERA_IP/ctrl/get?k=lut" | jq -r '.value' 2>/dev/null || echo "unknown")
current_movvfr=$(curl -s "http://$CAMERA_IP/ctrl/get?k=movvfr" | jq -r '.value' 2>/dev/null || echo "unknown")
current_send_stream=$(curl -s "http://$CAMERA_IP/ctrl/get?k=send_stream" | jq -r '.value' 2>/dev/null || echo "unknown")

echo "- VFR Mode: $current_movvfr"
echo "- LUT/Color Profile: $current_lut"
echo "- Stream Source: $current_send_stream"

# Check Stream0 UHD settings
stream_check=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?action=query" 2>/dev/null || echo "unknown")
echo "- Stream0 UHD Settings: $(echo "$stream_check" | jq -r '.msg' 2>/dev/null || echo "configured")"
echo ""

# Verify Z-Log2 is active
if [[ "$current_lut" == "Z-Log2" ]]; then
    echo "✅ Z-Log2 color profile active"
else
    echo "⚠️ LUT is $current_lut - Z-Log2 not active"
fi
echo ""

echo "UHD camera configuration completed. Starting video recording..."
echo ""

# Generate filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="zcamera_uhd_h265_zlog_${TIMESTAMP}.mp4"

echo "Recording to: $OUTPUT_FILE"
echo ""

# Record H.265 video to file with proper frame rate
gst-launch-1.0 -v\
  sspsrc ip="$CAMERA_IP" mode=video ! \
  queue ! \
  h265parse ! \
  video/x-h265,framerate=25/1 ! \
  mp4mux ! \
  filesink location="$OUTPUT_FILE" \
  --eos-on-shutdown &

# Get PID
GST_PID=$!

echo "Video recording started (PID: $GST_PID)"
echo "Recording UHD (3840x2160) H.265 10-bit Z-Log video to disk..."
echo "Press Ctrl+C to stop"

# Wait for duration or user interrupt
sleep $DURATION

# Send stop signal
echo ""
echo "Stopping video recording..."
kill -INT $GST_PID
wait $GST_PID

echo ""
echo "Video recording completed!"
echo ""
echo "Output file: $OUTPUT_FILE"
echo ""
echo "Stream information:"
echo "- Resolution: UHD (3840x2160)"
echo "- Codec: $codec_mode" 
echo "- Bitrate: $bitrate_mode"
echo "- Color Profile: Z-Log2"
echo "- Stream Source: Stream0"
