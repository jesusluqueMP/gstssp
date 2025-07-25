#!/bin/bash

# Z-Camera H.264 1080p Capture Script
# This script configures the car H.264 1080p and captures the stream

set +e  # Don't exit on errors - continue trying different methods

# Configuration
CAMERA_IP="192.168.1.34"
export GST_PLUGIN_PATH="$PWD/build/src"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_command() { echo -e "${BLUE}[CMD]${NC} $1"; }

# Cleanup function
cleanup() {
    print_status "Cleaning up camera session..."
    curl -s "http://$CAMERA_IP/ctrl/session?action=quit" > /dev/null 2>&1 || true
    exit 0
}

# Set up signal handling for cleanup
trap cleanup INT TERM

# Function to send camera command
send_camera_command() {
    local endpoint="$1"
    local description="$2"
    
    print_command "curl -s \"http://$CAMERA_IP$endpoint\""
    local response=$(curl -s "http://$CAMERA_IP$endpoint")
    
    if [ $? -eq 0 ]; then
        if echo "$response" | grep -q '"code":0' 2>/dev/null || echo "$response" | grep -q '"code":-1' 2>/dev/null; then
            print_status "$description - Response: $response"
        else
            print_warning "$description - Response: $response"
        fi
    else
        print_error "$description - Failed"
        return 1
    fi
    sleep 1
}

echo "========================================================"
echo "Z-Camera H.264 1080p Configuration & Capture"
echo "========================================================"

# Check camera connectivity
print_status "Checking camera connectivity..."
if ! curl -s --connect-timeout 5 "http://$CAMERA_IP/info" > /dev/null; then
    print_error "Camera not reachable at $CAMERA_IP"
    exit 1
fi
print_status "Camera is reachable"

# *** CRITICAL: Occupy session to prevent conflicts ***
print_status "Taking control of camera session..."
send_camera_command "/ctrl/session?action=occupy" "Occupy camera session"

# Configure camera for H.264 1080p
print_status "Configuring camera for H.264 1080p..."

# Exit standby and enter recording mode
send_camera_command "/ctrl/mode?action=exit_standby" "Exit standby mode"
send_camera_command "/ctrl/mode?action=to_rec" "Switch to recording mode"

# Set movie format to 1080p25 (since camera uses 25fps)
send_camera_command "/ctrl/set?movfmt=1080P25" "Set movie format to 1080P25"

# Turn off variable frame rate
send_camera_command "/ctrl/set?movvfr=Off" "Disable VFR"

# Configure stream0 for H.264 1080p with high bitrate (25 Mbps)
send_camera_command "/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=25000000&gop_n=30" "Configure stream0 for H.264 1080p"

# Enable stream0
send_camera_command "/ctrl/set?send_stream=Stream0" "Enable Stream0"

# Set optimal image profile
send_camera_command "/ctrl/set?lut=Rec.709" "Set Rec.709 profile"

print_status "Waiting for camera to stabilize..."
sleep 3

# Verify stream0 configuration
print_status "Verifying stream0 configuration..."
response=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&action=query")
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

# Skip recording - focus on streaming only (no SD card needed)
print_status "Testing if recording is needed for SSP streaming..."

# Try starting recording first to activate stream, then test if SSP works
print_status "Method: Starting recording to activate SSP stream..."
send_camera_command "/ctrl/rec?action=start_no_record" "Start streaming mode without recording"
if [ $? -ne 0 ]; then
    # If no_record mode not available, try regular recording briefly
    print_status "Fallback: Try brief recording to activate stream..."
    send_camera_command "/ctrl/rec?action=start" "Start recording briefly"
    sleep 2
    print_status "Now testing SSP while recording is active..."
fi

# *** CRITICAL: Start SSP streaming service for stream0 ***
print_status "Starting SSP streaming service for stream0..."
send_camera_command "/ctrl/stream_setting?action=start&index=stream0" "Start SSP streaming for stream0"

print_status "Waiting for SSP service to activate..."
sleep 3

# Check if stream0 is idle and try additional activation methods
if echo "$response" | grep -q '"status":"idle"'; then
    print_warning "Stream0 is idle, trying additional activation methods..."
    
    # Method 1: Ensure SSP service is enabled at system level
    print_status "Method 1: Checking/enabling SSP service..."
    send_camera_command "/ctrl/set?ssp_enable=1" "Enable SSP service (if available)"
    sleep 1
    
    # Method 2: Try starting recording temporarily to activate streaming
    print_status "Method 2: Trying temporary recording to activate stream..."
    send_camera_command "/ctrl/rec?action=start" "Start recording to activate stream"
    sleep 2
    send_camera_command "/ctrl/rec?action=stop" "Stop recording (keep stream active)"
    sleep 1
    
    # Method 1: Try different stream activation approaches
    print_status "Method 1: Trying stream reactivation..."
    send_camera_command "/ctrl/set?send_stream=none" "Disable streaming"
    sleep 1
    send_camera_command "/ctrl/set?send_stream=Stream0" "Re-enable Stream0"
    sleep 2
    
    # Check status
    response2=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&action=query")
    echo "Stream status after reactivation:"
    echo "$response2" | python3 -m json.tool 2>/dev/null || echo "$response2"
    
    # Method 2: Try different bitrate/settings to trigger activation
    if echo "$response2" | grep -q '"status":"idle"'; then
        print_status "Method 2: Trying lower bitrate settings..."
        send_camera_command "/ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h264&bitwidth=8&bitrate=10000000&gop_n=25" "Configure with 10Mbps H.264 bitrate"
        sleep 2
        
        # Method 3: Try forcing stream with backup option
        print_status "Method 3: Trying backup stream option..."
        send_camera_command "/ctrl/set?send_stream=Stream0_with_backup" "Enable Stream0 with backup"
        sleep 2
        
        # Method 4: Try different image profiles that might trigger streaming
        print_status "Method 4: Trying different image profiles..."
        send_camera_command "/ctrl/set?lut=Z-Log2" "Set Z-Log2 profile"
        sleep 1
        send_camera_command "/ctrl/set?lut=Rec.709" "Reset to Rec.709 profile"
        sleep 1
        
        # Final status check
        response3=$(curl -s "http://$CAMERA_IP/ctrl/stream_setting?index=stream0&action=query")
        echo "Final stream status:"
        echo "$response3" | python3 -m json.tool 2>/dev/null || echo "$response3"
        
        # If still idle, continue anyway - some cameras stream despite showing "idle"
        if echo "$response3" | grep -q '"status":"idle"'; then
            print_warning "Stream still shows 'idle' but continuing - some cameras stream anyway"
        fi
    fi
fi

# Additional diagnostics before attempting GStreamer
print_status "Running network diagnostics..."
print_command "Testing SSP port connectivity..."
if nc -z -v -w5 $CAMERA_IP 9999 2>&1; then
    print_status "SSP port 9999 is accessible"
else
    print_error "SSP port 9999 is not accessible - this explains the TCP connection failure"
    print_status "Checking if camera has SSP service enabled..."
    
    # Check camera network settings
    network_info=$(curl -s "http://$CAMERA_IP/ctrl/network?action=info" 2>/dev/null || echo "")
    if [ -n "$network_info" ]; then
        echo "Network info: $network_info"
    fi
    
    print_error "SSP service may not be available on this camera firmware"
    print_status "Attempting alternative streaming methods..."
    
    # Try RTSP if available
    print_status "Checking for RTSP stream..."
    if timeout 5s gst-launch-1.0 rtspsrc location=rtsp://$CAMERA_IP/live_stream ! fakesink 2>/dev/null; then
        print_status "RTSP stream is available - you can use: gst-launch-1.0 rtspsrc location=rtsp://$CAMERA_IP/live_stream ! h264parse ! avdec_h264 ! autovideosink"
    else
        print_warning "RTSP stream not available either"
    fi
    
    exit 1
fi

# Test GStreamer pipeline with better error handling
print_status "Testing GStreamer H.264 pipeline..."

# Enable debug output
export GST_DEBUG=sspsrc:4

print_status "Method 1: Testing SSP connection with extended timeout (no recording needed)..."
if timeout 20s gst-launch-1.0 -v sspsrc ip="$CAMERA_IP" mode=video ! fakesink dump=true 2>&1 | tee /tmp/gst_debug.log; then
    print_status "SSP connection successful - data received!"
    
    # Check what codec was detected
    if grep -q "video/x-h264" /tmp/gst_debug.log; then
        print_status "✅ H.264 stream detected!"
    elif grep -q "video/x-h265" /tmp/gst_debug.log; then
        print_status "ℹ️  H.265 stream detected (not H.264)"
    fi
    
else
    print_error "SSP connection failed"
    print_status "Debug output:"
    tail -15 /tmp/gst_debug.log 2>/dev/null || echo "No debug log available"
    
    # Check for specific error patterns
    if grep -q "No metadata received" /tmp/gst_debug.log 2>/dev/null; then
        print_warning "Camera is not sending stream metadata - stream may not be active"
        print_status "This is normal if no SD card is present or camera is not in streaming mode"
    elif grep -q "code=-1002" /tmp/gst_debug.log 2>/dev/null; then
        print_error "TCP connection failed - SSP service not available"
        print_status "This camera firmware may not support SSP streaming"
        return 1
    fi
fi

print_status "Method 2: Attempting H.264 decode and display with error handling..."
if gst-launch-1.0 -v sspsrc ip="$CAMERA_IP" mode=video ! h264parse ! avdec_h264 ! videoconvert ! autovideosink sync=false &
then
    PIPELINE_PID=$!
    
    # Let it run for 15 seconds then check if still running
    sleep 15
    if kill -0 $PIPELINE_PID 2>/dev/null; then
        print_status "Pipeline running successfully! Stopping after 15 seconds..."
        kill $PIPELINE_PID
        wait $PIPELINE_PID 2>/dev/null || true
    else
        print_warning "Pipeline exited early"
    fi
else
    print_error "Failed to start H.264 pipeline"
fi

print_status "Method 3: Saving H.264 stream to file..."
timeout 30s gst-launch-1.0 -e sspsrc ip="$CAMERA_IP" mode=video ! h264parse ! mp4mux ! filesink location=h264_capture_$(date +%Y%m%d_%H%M%S).mp4 || print_warning "File capture failed or timed out"

print_status "Capture test completed!"

# Clean up session
cleanup
