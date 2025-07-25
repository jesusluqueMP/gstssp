#!/bin/bash

# Z-Camera Z-Log Recording Script
# Records maximum quality H.265 10-bit with Z-Log2 color profile

set -e

CAMERA_IP="192.168.1.34"
DURATION=${1:-30}
OUTPUT_FILE=${2:-"zlog_recording_$(date +%Y%m%d_%H%M%S).mp4"}

echo "Z-Camera Z-Log2 Recording"
echo "========================"
echo "Duration: ${DURATION} seconds"
echo "Output: ${OUTPUT_FILE}"
echo "Camera: ${CAMERA_IP}"
echo ""

# Function to set camera parameter with error checking
set_camera_param() {
    local key=$1
    local value=$2
    local description=$3
    
    echo "Setting ${description}..."
    response=$(curl -s "http://${CAMERA_IP}/ctrl/set?k=${key}&v=${value}")
    code=$(echo "$response" | jq -r '.code' 2>/dev/null || echo "unknown")
    
    if [ "$code" = "0" ]; then
        echo "✅ ${description} set successfully"
    else
        echo "⚠️ ${description} failed: $response"
    fi
}

# Function to get camera parameter
get_camera_param() {
    local key=$1
    curl -s "http://${CAMERA_IP}/ctrl/get?k=${key}" | jq -r '.value' 2>/dev/null || echo "unknown"
}

echo "Configuring camera for Z-Log2 recording..."

# Set Z-Log2 color profile (most important for Z-Log recording)
set_camera_param "lut" "Z-Log2" "Z-Log2 color profile"

# Set H.265 codec for maximum quality
set_camera_param "encode" "265" "H.265 codec"

# Set maximum bitrate for proxy/stream
set_camera_param "pxy_bitrate" "60000000" "maximum proxy bitrate (60Mbps)"

# Set high quality proxy format
set_camera_param "pxy_fmt" "1080P25" "proxy format to 1080P25"

# Enable HDR if available
set_camera_param "hdr" "1" "HDR mode"

# Set maximum ISO for better low-light performance with Z-Log
set_camera_param "iso" "6400" "ISO 6400"

# Set shutter speed for 25fps (1/50s)
set_camera_param "shutter" "50" "shutter speed 1/50s"

# Set white balance for daylight (if recording outdoors)
set_camera_param "wb" "5600" "white balance 5600K"

# Wait for settings to take effect
echo "Waiting for camera settings to apply..."
sleep 3

# Display current settings
echo ""
echo "Current camera settings:"
echo "- LUT: $(get_camera_param 'lut')"
echo "- Codec: $(get_camera_param 'encode')"
echo "- Proxy bitrate: $(get_camera_param 'pxy_bitrate')"
echo "- Proxy format: $(get_camera_param 'pxy_fmt')"
echo "- HDR: $(get_camera_param 'hdr')"
echo "- ISO: $(get_camera_param 'iso')"
echo "- Shutter: $(get_camera_param 'shutter')"
echo "- White balance: $(get_camera_param 'wb')"
echo ""

echo "Starting Z-Log2 recording..."

# Enhanced GStreamer pipeline for Z-Log2 recording
GST_DEBUG=sspsrc:5 gst-launch-1.0 -e -v \
    sspsrc ip=${CAMERA_IP} port=9999 name=src ! \
    queue max-size-buffers=100 max-size-time=5000000000 ! \
    h265parse config-interval=1 ! \
    queue max-size-buffers=50 ! \
    mp4mux ! \
    filesink location="${OUTPUT_FILE}" &

PIPELINE_PID=$!
echo "Recording started (PID: $PIPELINE_PID)"
echo "Recording Z-Log2 H.265 10-bit for ${DURATION} seconds..."
echo "Press Ctrl+C to stop early"

# Wait for specified duration
sleep ${DURATION}

# Send EOS signal for clean shutdown
echo ""
echo "Sending EOS signal for clean shutdown..."
kill -INT $PIPELINE_PID 2>/dev/null || true

# Wait for pipeline to finish
wait $PIPELINE_PID 2>/dev/null || true

echo ""
echo "Recording completed!"
echo "File: ${OUTPUT_FILE}"

# Check if file exists and show properties
if [ -f "${OUTPUT_FILE}" ]; then
    ls -lh "${OUTPUT_FILE}"
    echo ""
    
    echo "File properties:"
    ffprobe -v error -show_entries format=duration,bit_rate -show_entries stream=codec_name,profile,pix_fmt,width,height,color_space,color_transfer,color_primaries -of default=noprint_wrappers=1 "${OUTPUT_FILE}" 2>/dev/null || echo "Could not analyze file with ffprobe"
    
    echo ""
    echo "Checking for 10-bit encoding:"
    ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt,profile -of csv=p=0 "${OUTPUT_FILE}" 2>/dev/null || echo "Could not check encoding"
    
    # Check for Z-Log characteristics
    if ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "${OUTPUT_FILE}" 2>/dev/null | grep -q "10le"; then
        echo "✅ 10-bit detected!"
    else
        echo "⚠️ 10-bit not detected"
    fi
    
    if ffprobe -v error -select_streams v:0 -show_entries stream=profile -of csv=p=0 "${OUTPUT_FILE}" 2>/dev/null | grep -q "Main 10"; then
        echo "✅ H.265 Main 10 profile detected!"
    else
        echo "⚠️ H.265 Main 10 profile not detected"
    fi
else
    echo "❌ Recording file not found!"
fi

echo ""
echo "Z-Log2 recording summary:"
echo "- Color profile: Z-Log2 (wide dynamic range)"
echo "- Codec: H.265/HEVC 10-bit"
echo "- Container: MP4"
echo "- Post-processing: Import into DaVinci Resolve or similar for Z-Log2 color grading"
echo ""
echo "Note: Z-Log2 files will appear flat/desaturated - this is normal!"
echo "Apply Z-Log2 to Rec.709 LUT in post-production for proper colors."
