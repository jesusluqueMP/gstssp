# GStreamer SSP Plugin

This plugin provides a GStreamer source element for receiving video and audio streams from Z CAM cameras using the Simple Stream Protocol (SSP).

## Features

- Support for H.264 and H.265 video streams with auto-detection
- Support for AAC and PCM audio streams
- Live streaming with proper timestamping
- Configurable stream styles (default, main, secondary)
- Support for video-only, audio-only, or combined modes
- Automatic codec detection from stream data
- Dynamic caps negotiation for codec changes
- Cross-platform support (macOS, Linux, Windows)

## Requirements

### System Dependencies
- GStreamer 1.16.0 or later
- GStreamer development packages
- Meson build system
- Ninja build tool
- C++11 compatible compiler

### macOS Installation
```bash
brew install gstreamer gst-plugins-base gst-plugins-good
brew install meson ninja
```

### Ubuntu/Debian Installation
```bash
sudo apt update
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
sudo apt install meson ninja-build
```

## Building

1. Clone or extract the project
2. Navigate to the project directory
3. Run the build script:
   ```bash
   ./build.sh
   ```

Or manually:
```bash
meson setup build
meson compile -C build
```

## Installation

```bash
sudo meson install -C build
```

Or for development/testing without system installation:
```bash
export GST_PLUGIN_PATH=$PWD/build/src
```

## Usage

### Basic Usage

```bash
# Test plugin installation
gst-inspect-1.0 sspsrc

# Simple video stream
gst-launch-1.0 sspsrc ip=192.168.1.100 mode=video ! h264parse ! avdec_h264 ! videoconvert ! autovideosink

# Simple audio stream
gst-launch-1.0 sspsrc ip=192.168.1.100 mode=audio ! aacparse ! avdec_aac ! audioconvert ! autoaudiosink

# Combined video and audio (requires demuxer/splitter)
gst-launch-1.0 sspsrc ip=192.168.1.100 mode=both ! ...
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| ip | string | "192.168.1.100" | IP address of the Z CAM camera |
| port | uint | 9999 | Port number for SSP connection |
| stream-style | enum | default | Stream style: default, main, secondary |
| mode | enum | both | Output mode: video, audio, both |
| buffer-size | uint | 0x400000 | Receive buffer size |
| capability | uint | 0 | SSP capability flags |
| is-hlg | boolean | false | Enable HLG mode |

### Stream Styles
- **default**: Default stream from camera
- **main**: Main stream (usually higher quality)
- **secondary**: Secondary stream (usually lower quality)

### Output Modes
- **video**: Video data only
- **audio**: Audio data only  
- **both**: Both video and audio data

## Examples

### Auto-Detection Pipeline (Recommended)
```bash
# Automatically detects H.264 or H.265 and uses appropriate decoder
gst-launch-1.0 sspsrc ip=192.168.9.86 port=9999 mode=video \
  ! queue ! decodebin ! videoconvert ! autovideosink
```

### H.264 Specific Pipeline
```bash
gst-launch-1.0 sspsrc ip=192.168.9.86 port=9999 mode=video \
  ! h264parse ! avdec_h264 ! videoconvert ! autovideosink
```

### H.265 Specific Pipeline
```bash
gst-launch-1.0 sspsrc ip=192.168.9.86 port=9999 mode=video \
  ! h265parse ! avdec_h265 ! videoconvert ! autovideosink
```

### Save Video to File (Auto-format)
```bash
gst-launch-1.0 sspsrc ip=192.168.9.86 mode=video \
  ! queue ! decodebin ! videoconvert ! x264enc ! mp4mux ! filesink location=output.mp4
```

### H.265 to H.264 Transcoding
```bash
gst-launch-1.0 sspsrc ip=192.168.9.86 mode=video \
  ! h265parse ! avdec_h265 ! videoconvert \
  ! x264enc bitrate=2000 ! h264parse ! mp4mux ! filesink location=transcoded.mp4
```

### Audio Only Pipeline
```bash
gst-launch-1.0 sspsrc ip=192.168.9.86 mode=audio \
  ! aacparse ! avdec_aac ! audioconvert ! autoaudiosink
```

### RTMP Streaming
```bash
gst-launch-1.0 sspsrc ip=192.168.9.86 mode=video \
  ! h264parse ! flvmux ! rtmpsink location=rtmp://localhost/live/stream
```

## H.265 Testing

For comprehensive H.265 testing, use the dedicated test script:

```bash
./examples/test_h265.sh
```

This script provides:
- H.265 capability testing
- Codec detection from stream
- Auto-detection pipeline testing
- Forced H.265 pipeline testing
- H.265 recording
- H.265 to H.264 transcoding
- Performance testing

### H.265 Requirements

Ensure you have H.265 support installed:

**macOS:**
```bash
brew install gst-libav gst-plugins-bad
```

**Ubuntu/Debian:**
```bash
sudo apt install gstreamer1.0-libav gstreamer1.0-plugins-bad
```

## Troubleshooting

### Plugin Not Found
```bash
# Check if plugin is in the path
export GST_PLUGIN_PATH=$PWD/build/src
gst-inspect-1.0 sspsrc

# Or check system plugin directories
gst-inspect-1.0 --print-all | grep ssp
```

### Connection Issues
- Verify camera IP address and port
- Ensure camera is on the same network
- Check firewall settings
- Verify camera supports SSP protocol

### H.265 Issues
```bash
# Check if H.265 decoder is available
gst-inspect-1.0 avdec_h265

# Check if H.265 parser is available  
gst-inspect-1.0 h265parse

# Test H.265 capability
./examples/test_h265.sh
```

### Debug Information
```bash
export GST_DEBUG=sspsrc:5
gst-launch-1.0 sspsrc ip=192.168.9.86 ! ...
```

## Development

### Project Structure
```
gst-ssp/
├── src/
│   ├── gstsspsrc.cpp      # Main source element
│   ├── gstsspsrc.h        # Source element header
│   ├── gstsspplugin.c     # Plugin registration
│   ├── sspthread.cpp      # SSP thread wrapper
│   ├── sspthread.h        # SSP thread header
│   └── meson.build        # Source build config
├── libssp/                # SSP library (external)
├── meson.build            # Main build config
├── build.sh               # Build script
└── README.md              # This file
```

### Adding Features
The plugin is designed to be extensible. Key areas for enhancement:
- Additional stream formats
- Advanced error handling
- Stream reconnection logic
- Statistics and monitoring
- Custom pad templates

## License

This plugin is released under the LGPL license, compatible with GStreamer's licensing.

## Support

For issues related to:
- **GStreamer plugin**: Check GStreamer documentation and this README
- **SSP protocol**: Refer to Z CAM documentation
- **libssp library**: Contact the library maintainer

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

Please ensure your code follows GStreamer coding standards and includes appropriate documentation.
