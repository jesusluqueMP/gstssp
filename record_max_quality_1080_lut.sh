#!/bin/bash

# Z-Camera 1080p H.265 10-bit HDR Z-Log Display Script with OCIO LUT
# Based on record_max_quality.sh but modified for 1080p with OCIO LUT support
# Usage: ./record_max_quality_1080_lut.sh [duration] [camera_ip]

DURATION=${1:-30}
CAMERA_IP=${2:-"192.168.1.34"}
LUT_FILE="$PWD/luts/Z-Log2/normal/zLog2_zRGB-ax2_64.cube"

echo "Z-Camera 1080p H.265 10-bit HDR Z-Log Display with OCIO LUT"
echo "=========================================================="
echo "Duration: ${DURATION} seconds"
echo "Camera: $CAMERA_IP"
echo "LUT File: $LUT_FILE"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

# Check if LUT file exists
if [ ! -f "$LUT_FILE" ]; then
    echo "❌ Error: LUT file not found at $LUT_FILE"
    exit 1
fi

echo "✅ Using Z-Log2 to sRGB LUT: $(basename "$LUT_FILE")"

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

echo "Configuring camera for 1080p 10-bit Z-Log..."

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

# Function to set stream parameter for 1080p configuration
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

# 4. Configure Stream0 for 1080p H.265 following zdump pattern
echo "Configuring Stream0 for 1080p H.265 (following zdump pattern)..."

# Set movie format first (like zdump does)
set_param "movfmt" "1080P25" "1080p 25fps movie format"
sleep 0.5

# Configure Stream0 with all parameters in one call (zdump style)
bitrate_bps=$((100 * 1000 * 1000))  # 100 Mbps in bps for 1080p
stream_config_url="index=stream0&fps=25&width=1920&height=1080&venc=h265&bitwidth=10&bitrate=${bitrate_bps}&gop_n=1"

echo "Setting Stream0 parameters:"
echo "  - Resolution: 1920x1080 (1080p)"
echo "  - Codec: H.265 (venc=h265)" 
echo "  - Bit Width: 10-bit (bitwidth=10)"
echo "  - Bitrate: 100 Mbps"
echo "  - GOP: 1 frame (I-frame only for maximum quality)"

response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config_url")
code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")

if [ "$code" = "0" ]; then
    echo "✅ Stream0 H.265 10-bit 1080p configuration successful"
    codec_mode="H.265 10-bit"
    bitrate_mode="100 Mbps"
    else
        echo "⚠️ H.265 10-bit failed, trying H.265 8-bit..."
        # Fallback to H.265 8-bit
        bitrate_bps=$((80 * 1000 * 1000))  # 80 Mbps in bps
        stream_config_url="index=stream0&fps=25&width=1920&height=1080&venc=h265&bitwidth=8&bitrate=${bitrate_bps}&gop_n=1"
        
        response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config_url")
        code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")
        
        if [ "$code" = "0" ]; then
            echo "✅ Stream0 H.265 8-bit 1080p configuration successful"
            codec_mode="H.265 8-bit"
            bitrate_mode="80 Mbps"
        else
            echo "⚠️ H.265 failed, falling back to H.264..."
            # Final fallback to H.264
            stream_config_url="index=stream0&fps=25&width=1920&height=1080&venc=h264&bitwidth=8&bitrate=${bitrate_bps}&gop_n=1"
        curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config_url" > /dev/null
        echo "✅ Stream0 H.264 8-bit 1080p configuration set (fallback)"
        codec_mode="H.264 8-bit (fallback)"
        bitrate_mode="80 Mbps"
    fi
fi

echo "   - Stream0 is primary recording stream"
echo "   - Resolution: 1920x1080 (1080p)"
echo "   - Codec: $codec_mode"
echo "   - Bitrate: $bitrate_mode"
echo "   - FPS: 25"

sleep 1

# 5. Use Stream0 as network streaming source
set_param "send_stream" "Stream0" "Stream0 as 1080p source"
sleep 2

# 6. Wait for stream to stabilize before recording
echo "Waiting for 1080p stream to initialize..."
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

# Check Stream0 1080p settings
stream_check=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?action=query" 2>/dev/null || echo "unknown")
echo "- Stream0 1080p Settings: $(echo "$stream_check" | jq -r '.msg' 2>/dev/null || echo "configured")"
echo ""

# Verify Z-Log2 is active
if [[ "$current_lut" == "Z-Log2" ]]; then
    echo "✅ Z-Log2 color profile active"
else
    echo "⚠️ LUT is $current_lut - Z-Log2 not active"
fi
echo ""

# Test OCIO plugin availability
echo "Testing OCIO plugin..."
gst-launch-1.0 -e videotestsrc num-buffers=10 ! video/x-raw,format=RGB,width=640,height=480,framerate=25/1 ! ocio lut-file="$LUT_FILE" use-gpu=true ! videoconvert ! fakesink > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ OCIO plugin working with GPU acceleration"
    USE_GPU=true
else
    echo "⚠️ OCIO GPU failed, trying CPU..."
    gst-launch-1.0 -e videotestsrc num-buffers=10 ! video/x-raw,format=RGB,width=640,height=480,framerate=25/1 ! ocio lut-file="$LUT_FILE" use-gpu=false ! videoconvert ! fakesink > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ OCIO plugin working with CPU"
        USE_GPU=false
    else
        echo "❌ OCIO plugin not working, will record without LUT"
        USE_OCIO=false
    fi
fi

echo "1080p camera configuration completed. Starting video recording with OCIO LUT..."
echo ""

# Generate filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="zcamera_1080p_h265_zlog_lut_${TIMESTAMP}.mp4"

echo "Recording to: $OUTPUT_FILE"
echo ""

# Build pipeline based on OCIO availability
if [ "$USE_OCIO" != "false" ]; then
    if [ "$USE_GPU" = "true" ]; then
        echo "Using OCIO LUT with GPU acceleration..."
        OCIO_ELEMENT="ocio lut-file=\"$LUT_FILE\" use-gpu=true"
    else
        echo "Using OCIO LUT with CPU processing..."
        OCIO_ELEMENT="ocio lut-file=\"$LUT_FILE\" use-gpu=false"
    fi
    
    # Pipeline with OCIO LUT for live display and recording
    gst-launch-1.0 -v \
      sspsrc ip="$CAMERA_IP" mode=video ! \
      queue max-size-buffers=10 ! \
      h265parse ! \
      avdec_h265 ! \
      videoconvert ! \
      videorate ! \
      video/x-raw,format=RGB,framerate=25/1 ! \
      tee name=t ! \
      queue max-size-buffers=5 leaky=2 ! \
      videorate ! video/x-raw,framerate=25/1 ! \
      $OCIO_ELEMENT ! \
      videorate ! video/x-raw,framerate=25/1 ! \
      videoconvert ! \
      autovideosink sync=false \
      t. ! queue max-size-buffers=5 leaky=2 ! \
      videoconvert ! \
      videorate ! video/x-raw,framerate=25/1 ! \
      x265enc bitrate=30000 tune=psnr speed-preset=medium ! \
      h265parse ! \
      video/x-h265,stream-format=hvc1,framerate=25/1 ! \
      mp4mux ! \
      filesink location="$OUTPUT_FILE" \
      --eos-on-shutdown &
else
    echo "Recording without OCIO LUT (fallback mode)..."
    # Fallback pipeline without OCIO
    gst-launch-1.0 -v \
      sspsrc ip="$CAMERA_IP" mode=video ! \
      queue ! \
      h265parse ! \
      videorate ! video/x-h265,framerate=25/1 ! \
      tee name=t ! \
      queue ! \
      avdec_h265 ! \
      videoconvert ! \
      videorate ! video/x-raw,framerate=25/1 ! \
      autovideosink sync=false \
      t. ! queue ! \
      video/x-h265,stream-format=hvc1,framerate=25/1 ! \
      mp4mux ! \
      filesink location="$OUTPUT_FILE" \
      --eos-on-shutdown &
fi

# Get PID
GST_PID=$!

echo "Video recording started (PID: $GST_PID)"
echo "Recording 1080p H.265 10-bit Z-Log video with OCIO LUT display..."
echo "Press Ctrl+C to stop"

if [ "$USE_OCIO" != "false" ]; then
    echo "✅ Live display with Z-Log2 to sRGB LUT conversion"
    if [ "$USE_GPU" = "true" ]; then
        echo "✅ Using GPU acceleration for OCIO"
    else
        echo "⚠️ Using CPU processing for OCIO"
    fi
else
    echo "⚠️ Live display with raw Z-Log2 (no color correction)"
fi

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
ls -lh "$OUTPUT_FILE"
echo ""
echo "Stream information:"
echo "- Resolution: 1080p (1920x1080)"
echo "- Codec: $codec_mode" 
echo "- Bitrate: $bitrate_mode"
echo "- Color Profile: Z-Log2"
echo "- Stream Source: Stream0"
echo "- LUT Applied: Z-Log2 to sRGB conversion"
if [ "$USE_GPU" = "true" ]; then
    echo "- OCIO Acceleration: GPU"
else
    echo "- OCIO Acceleration: CPU"
fi
echo ""
echo "File properties:"
ffprobe "$OUTPUT_FILE" 2>&1 | grep -E "(Duration|Video|bitrate)" | head -3
