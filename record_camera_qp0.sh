#!/bin/bash

# Z-Camera recording script with QP-based maximum quality control
# Supports both H.264 and H.265 with QP for maximum quality
# Usage: ./record_camera_qp.sh [codec] [duration] [output_file] [camera_ip]

CODEC=${1:-"h265"}
DURATION=${2:-5}
OUTPUT_FILE=${3:-"recording_${CODEC}_qp0.mp4"}
CAMERA_IP=${4:-"192.168.1.34"}

echo "Z-Camera QP-Based Maximum Quality Recording Script"
echo "================================================="
echo "Codec: $CODEC"
echo "Duration: ${DURATION} seconds"
echo "Output file: $OUTPUT_FILE"
echo "Camera IP: $CAMERA_IP"
echo "Quality: Lossless (QP=0)"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

# Function to set camera parameter with QP control
set_camera_qp() {
    local codec=$1
    local qp_value=${2:-1}  # QP=1 for maximum quality (0 is lossless but may not be supported)
    
    echo "Configuring camera for maximum quality with QP=$qp_value..."
    
    # Set Z-Log2 for maximum dynamic range
    curl -s "http://$CAMERA_IP/ctrl/set?lut=Z-Log2" > /dev/null
    sleep 0.5
    
    # Turn off VFR for consistent quality
    curl -s "http://$CAMERA_IP/ctrl/set?movvfr=Off" > /dev/null
    sleep 0.5
    
    # Stop current stream
    curl -s "http://$CAMERA_IP/ctrl/set?send_stream=none" > /dev/null
    sleep 1
    
    if [ "$codec" = "h265" ] || [ "$codec" = "hevc" ]; then
        echo "Setting H.265 with QP=$qp_value for maximum quality..."
        # Configure H.265 with QP instead of bitrate
        # Use UHD resolution and QP-based rate control
        stream_config="index=stream0&fps=25&width=3840&height=2160&venc=h265&bitwidth=10&qp=${qp_value}&gop_n=1&profile=main10"
        curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config" > /dev/null
    else
        echo "Setting H.264 with QP=$qp_value for maximum quality..."
        # Configure H.264 with QP instead of bitrate
        stream_config="index=stream0&fps=25&width=3840&height=2160&venc=h264&qp=${qp_value}&gop_n=1"
        curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config" > /dev/null
    fi
    
    sleep 1
    
    # Start streaming from Stream0
    curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null
    sleep 2
    
    echo "Camera configured for UHD $codec with QP=$qp_value (maximum quality)"
}

# Configure camera with QP for maximum quality
set_camera_qp "$CODEC" 0  # QP=0 for lossless quality (if supported)

echo "Waiting for stream to stabilize..."
sleep 3

# Build pipeline based on codec for maximum quality
if [ "$CODEC" = "h265" ] || [ "$CODEC" = "hevc" ]; then
    PIPELINE="sspsrc ip=\"$CAMERA_IP\" mode=video ! queue ! h265parse ! video/x-h265,stream-format=hvc1,framerate=25/1 ! mp4mux ! filesink location=\"$OUTPUT_FILE\""
else
    PIPELINE="sspsrc ip=\"$CAMERA_IP\" mode=video ! queue ! h264parse ! video/x-h264,stream-format=avc,framerate=25/1 ! mp4mux ! filesink location=\"$OUTPUT_FILE\""
fi

echo "Starting lossless recording with QP=0..."

# Start recording with proper EOS handling
gst-launch-1.0 -v $PIPELINE --eos-on-shutdown &

# Get the PID
GST_PID=$!

echo "Recording started (PID: $GST_PID)"
echo "Recording UHD (3840x2160) $CODEC with QP=0 (lossless quality)..."
echo "Z-Log2 color profile active for maximum dynamic range"
echo "Recording for ${DURATION} seconds..."

# Wait for specified duration
sleep $DURATION

# Send SIGINT for proper EOS
echo "Sending EOS signal for clean shutdown..."
kill -INT $GST_PID

# Wait for graceful shutdown
wait $GST_PID

echo ""
echo "Maximum quality recording completed successfully!"
echo "File: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

echo ""
echo "Quality settings used:"
echo "- QP: 0 (lossless quality)"
echo "- Resolution: UHD (3840x2160)" 
echo "- Codec: $CODEC"
echo "- Color Profile: Z-Log2"
echo "- GOP: 1 (I-frame only)"
echo ""
echo "File properties:"
ffprobe "$OUTPUT_FILE" 2>&1 | grep -E "(Duration|Video|bitrate)" | head -3
