#!/bin/bash

# Z-Camera UHD Live Display Script with QP-based quality and OCIO LUT
# Usage: ./record_camera_qp0_lut_display.sh [codec] [duration] [camera_ip]

CODEC=${1:-"h265"}
DURATION=${2:-0}
CAMERA_IP=${3:-"192.168.1.34"}
LUT_FILE="$PWD/luts/Z-Log2/normal/zLog2_zRGB-ax2_64.cube"

echo "Z-Camera UHD Live Display with OCIO LUT"
echo "======================================="
echo "Codec: $CODEC"
echo "Duration: ${DURATION} seconds (0 = continuous)"
echo "Camera IP: $CAMERA_IP"
echo "Quality: Maximum (QP=1)"
echo "LUT File: $LUT_FILE"
echo ""

# Set plugin path
export GST_PLUGIN_PATH="$PWD/build/src"

# Check requirements
echo "Checking requirements..."
if ! gst-inspect-1.0 sspsrc > /dev/null 2>&1; then
    echo "❌ Error: sspsrc plugin not found"
    exit 1
fi

if [ ! -f "$LUT_FILE" ]; then
    echo "❌ Error: LUT file not found at $LUT_FILE"
    exit 1
fi

echo "✅ Requirements OK"

# Configure camera for UHD
configure_camera() {
    echo "Configuring camera for UHD with QP=1..."
    
    # Get session and set movie format
    curl -s "http://$CAMERA_IP/ctrl/session?action=occupy" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?movfmt=4KP25" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?lut=Z-Log2" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?movvfr=Off" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?send_stream=none" > /dev/null
    sleep 2
    
    # Configure stream
    if [ "$CODEC" = "h265" ]; then
        stream_config="index=stream0&fps=25&width=3840&height=2160&venc=h265&bitwidth=10&qp=1&gop_n=1&profile=main10"
    else
        stream_config="index=stream0&fps=25&width=3840&height=2160&venc=h264&qp=1&gop_n=1"
    fi
    
    curl -s "http://$CAMERA_IP/ctrl/stream_setting?$stream_config" > /dev/null
    curl -s "http://$CAMERA_IP/ctrl/set?send_stream=Stream0" > /dev/null
    sleep 3
    
    echo "✅ Camera configured for UHD $CODEC"
}

# Configure camera
configure_camera

# Build pipeline
echo "Building display pipeline..."
if [ "$CODEC" = "h265" ]; then
    PARSER="h265parse"
    DECODER="avdec_h265"
else
    PARSER="h264parse"
    DECODER="avdec_h264"
fi

# Try OCIO with GPU first, then CPU, then no OCIO
PIPELINE_GPU="sspsrc ip=\"$CAMERA_IP\" mode=video ! queue ! $PARSER ! $DECODER ! videoconvert ! video/x-raw,format=RGB ! ocio lut-file=\"$LUT_FILE\" use-gpu=true ! videoconvert ! autovideosink sync=false"

PIPELINE_CPU="sspsrc ip=\"$CAMERA_IP\" mode=video ! queue ! $PARSER ! $DECODER ! videoconvert ! video/x-raw,format=RGB ! ocio lut-file=\"$LUT_FILE\" use-gpu=false ! videoconvert ! autovideosink sync=false"

PIPELINE_FALLBACK="sspsrc ip=\"$CAMERA_IP\" mode=video ! queue ! $PARSER ! $DECODER ! videoconvert ! autovideosink sync=false"

# Start display
echo "Starting UHD live display..."

# Try GPU OCIO first
echo "Attempting OCIO with GPU acceleration..."
gst-launch-1.0 $PIPELINE_GPU &
GST_PID=$!
sleep 2

if ! kill -0 $GST_PID 2>/dev/null; then
    echo "GPU failed, trying CPU OCIO..."
    gst-launch-1.0 $PIPELINE_CPU &
    GST_PID=$!
    sleep 2
    
    if ! kill -0 $GST_PID 2>/dev/null; then
        echo "CPU failed, using fallback (no LUT)..."
        gst-launch-1.0 $PIPELINE_FALLBACK &
        GST_PID=$!
        USING_LUT=false
    else
        echo "✅ Using CPU OCIO"
        USING_LUT=true
    fi
else
    echo "✅ Using GPU OCIO"
    USING_LUT=true
fi

echo ""
echo "🎥 Live UHD Display Active"
echo "Resolution: 3840x2160"
echo "Codec: $CODEC with QP=1"
echo "Color: Z-Log2 -> $([ "$USING_LUT" = "true" ] && echo "sRGB (LUT)" || echo "Raw")"

if [ "$DURATION" -eq 0 ]; then
    echo "Press Ctrl+C to stop"
    wait $GST_PID
else
    echo "Displaying for ${DURATION} seconds..."
    sleep $DURATION
    kill -INT $GST_PID 2>/dev/null
    wait $GST_PID 2>/dev/null
fi

echo "Display stopped."
