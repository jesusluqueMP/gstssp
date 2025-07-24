#!/bin/bash

# H.265 specific testing for GStreamer SSP Plugin

# Set plugin path if not installed system-wide
export GST_PLUGIN_PATH="$PWD/../build/src"

# Default camera IP
CAMERA_IP="192.168.9.86"

echo "H.265 Testing for GStreamer SSP Plugin"
echo "======================================"
echo ""

# Function to test H.265 capability
test_h265_capability() {
    echo "Testing H.265 decoding capability..."
    
    # Check if H.265 decoder is available
    if gst-inspect-1.0 avdec_h265 >/dev/null 2>&1; then
        echo "✓ H.265 decoder (avdec_h265) is available"
    else
        echo "✗ H.265 decoder not found"
        echo "Install: sudo apt install gstreamer1.0-libav (Ubuntu) or brew install gst-libav (macOS)"
        return 1
    fi
    
    # Check if H.265 parser is available
    if gst-inspect-1.0 h265parse >/dev/null 2>&1; then
        echo "✓ H.265 parser (h265parse) is available"
    else
        echo "✗ H.265 parser not found"
        echo "Install: sudo apt install gstreamer1.0-plugins-bad (Ubuntu)"
        return 1
    fi
    
    return 0
}

# Function to detect codec from stream
detect_codec() {
    local ip="$1"
    echo "Detecting codec from camera at $ip..."
    
    timeout 10s gst-launch-1.0 sspsrc ip="$ip" mode=video \
        ! fakesink dump=true 2>&1 | head -20
}

# Function to test with codec auto-detection
test_auto_detection() {
    local ip="$1"
    echo "Testing codec auto-detection..."
    echo "This will try to detect H.264 vs H.265 automatically."
    
    gst-launch-1.0 sspsrc ip="$ip" mode=video \
        ! queue ! identity silent=false \
        ! decodebin ! videoconvert ! autovideosink
}

# Function to force H.265 pipeline
test_h265_forced() {
    local ip="$1"
    echo "Testing forced H.265 pipeline..."
    
    gst-launch-1.0 sspsrc ip="$ip" mode=video \
        ! h265parse ! avdec_h265 ! videoconvert ! autovideosink
}

# Function to test H.265 recording
test_h265_recording() {
    local ip="$1"
    local output="h265_test_$(date +%Y%m%d_%H%M%S).mp4"
    
    echo "Recording H.265 stream to $output..."
    echo "Press Ctrl+C to stop recording."
    
    gst-launch-1.0 sspsrc ip="$ip" mode=video \
        ! h265parse ! mp4mux ! filesink location="$output"
    
    if [ -f "$output" ]; then
        echo "Recording saved to: $output"
        echo "File info:"
        ls -lh "$output"
        
        # Try to get media info if available
        if command -v mediainfo >/dev/null 2>&1; then
            mediainfo "$output" | grep -E "(Format|Width|Height|Frame rate|Bit rate)"
        elif command -v ffprobe >/dev/null 2>&1; then
            ffprobe -v quiet -show_format -show_streams "$output" | grep -E "(codec_name|width|height|bit_rate)"
        fi
    fi
}

# Function to test transcoding H.265 to H.264
test_h265_transcode() {
    local ip="$1"
    local output="h265_to_h264_$(date +%Y%m%d_%H%M%S).mp4"
    
    echo "Transcoding H.265 to H.264..."
    echo "Output: $output"
    echo "Press Ctrl+C to stop."
    
    gst-launch-1.0 sspsrc ip="$ip" mode=video \
        ! h265parse ! avdec_h265 ! videoconvert \
        ! x264enc bitrate=2000 speed-preset=fast \
        ! h264parse ! mp4mux ! filesink location="$output"
    
    if [ -f "$output" ]; then
        echo "Transcoded file: $output"
        ls -lh "$output"
    fi
}

# Main menu
echo "H.265 Test Options:"
echo "1. Test H.265 capability"
echo "2. Detect codec from stream"
echo "3. Auto-detection pipeline"
echo "4. Force H.265 pipeline"
echo "5. Record H.265 stream"
echo "6. Transcode H.265 to H.264"
echo "7. Performance test"
echo ""

read -p "Enter camera IP [$CAMERA_IP]: " ip_input
if [ -n "$ip_input" ]; then
    CAMERA_IP="$ip_input"
fi

read -p "Select test (1-7): " choice

case $choice in
    1)
        test_h265_capability
        ;;
    2)
        detect_codec "$CAMERA_IP"
        ;;
    3)
        test_auto_detection "$CAMERA_IP"
        ;;
    4)
        if test_h265_capability; then
            test_h265_forced "$CAMERA_IP"
        fi
        ;;
    5)
        if test_h265_capability; then
            test_h265_recording "$CAMERA_IP"
        fi
        ;;
    6)
        if test_h265_capability; then
            test_h265_transcode "$CAMERA_IP"
        fi
        ;;
    7)
        echo "Performance testing..."
        echo "This will run for 30 seconds and measure performance."
        
        timeout 30s gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h265parse ! avdec_h265 ! videoconvert \
            ! fpsdisplaysink video-sink=fakesink text-overlay=false
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
