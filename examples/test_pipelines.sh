#!/bin/bash

# Example GStreamer pipelines for SSP plugin

# Set plugin path if not installed system-wide
export GST_PLUGIN_PATH="$PWD/../build/src"

# Default camera IP - change this to your camera's IP
CAMERA_IP="192.168.9.86"

echo "GStreamer SSP Plugin Examples"
echo "============================="
echo ""
echo "Available examples:"
echo "1. Test plugin installation"
echo "2. Video preview (auto-detect H.264/H.265)"
echo "3. Audio preview"
echo "4. Save video to file"
echo "5. Save audio to file"
echo "6. RTMP streaming"
echo "7. UDP streaming"
echo "8. Debug mode"
echo "9. H.265 specific pipeline"
echo "10. H.265 to H.264 transcoding"
echo ""

read -p "Enter your choice (1-10): " choice
read -p "Enter camera IP address [$CAMERA_IP]: " ip_input

# Use default IP if none provided
if [ -n "$ip_input" ]; then
    CAMERA_IP="$ip_input"
fi

case $choice in
    1)
        echo "Testing plugin installation..."
        gst-inspect-1.0 sspsrc
        ;;
    2)
        echo "Starting video preview..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h264parse ! avdec_h264 ! videoconvert ! autovideosink
        ;;
    3)
        echo "Starting audio preview..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=audio \
            ! aacparse ! avdec_aac ! audioconvert ! autoaudiosink
        ;;
    4)
        echo "Saving video to output.mp4..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h264parse ! mp4mux ! filesink location=output.mp4
        ;;
    5)
        echo "Saving audio to output.aac..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=audio \
            ! aacparse ! filesink location=output.aac
        ;;
    6)
        read -p "Enter RTMP URL: " rtmp_url
        echo "Streaming to RTMP..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h264parse ! flvmux ! rtmpsink location="$rtmp_url"
        ;;
    7)
        read -p "Enter destination IP:port (e.g., 192.168.1.100:5000): " udp_dest
        echo "Streaming to UDP..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h264parse ! rtph264pay ! udpsink host="${udp_dest%:*}" port="${udp_dest#*:}"
        ;;
    8)
        echo "Running with debug output..."
        export GST_DEBUG=sspsrc:5
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h264parse ! avdec_h264 ! videoconvert ! autovideosink
        ;;
    9)
        echo "H.265 specific pipeline with parser..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h265parse ! avdec_h265 ! videoconvert ! autovideosink
        ;;
    10)
        echo "H.265 to H.264 transcoding..."
        gst-launch-1.0 sspsrc ip="$CAMERA_IP" mode=video \
            ! h265parse ! avdec_h265 ! videoconvert ! x264enc bitrate=2000 ! h264parse \
            ! mp4mux ! filesink location=transcoded_h264.mp4
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
