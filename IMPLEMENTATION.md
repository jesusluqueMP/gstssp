# GStreamer SSP Plugin Implementation Notes

## Overview

This implementation provides a complete GStreamer plugin for integrating the libssp library, which enables communication with Z CAM cameras using the Simple Stream Protocol (SSP).

## Architecture

### Core Components

1. **gstsspsrc.cpp/h** - Main GStreamer source element
   - Inherits from GstPushSrc for live streaming
   - Manages properties and element lifecycle
   - Handles caps negotiation for video/audio streams

2. **sspthread.cpp/h** - C++ wrapper for libssp
   - Bridges C++ libssp library with C GStreamer APIs
   - Manages the SSP client lifecycle and event loop
   - Provides callback mechanism for data and events

3. **gstsspplugin.c** - Plugin registration
   - Registers the sspsrc element with GStreamer
   - Provides plugin metadata and initialization

### Key Features

- **Multi-format Support**: H.264, H.265 video; AAC, PCM audio
- **Flexible Modes**: Video-only, audio-only, or combined streams
- **Live Streaming**: Proper timestamping and live source handling
- **Stream Selection**: Support for main/secondary streams
- **Cross-platform**: macOS, Linux, Windows support

## Technical Details

### Threading Model
- libssp runs in its own thread using ThreadLoop
- Data callbacks push buffers to async queues
- Main GStreamer thread pulls from queues in create() method

### Memory Management
- libssp data is copied to GStreamer buffers
- Memory is managed using gst_memory_new_wrapped with g_free
- Proper reference counting for all GStreamer objects

### Synchronization
- Mutex/condition variables for connection state
- Async queues for thread-safe buffer passing
- Proper unlock/unlock_stop for pipeline control

### Caps Negotiation
- Dynamic caps setting based on metadata callbacks
- Support for unknown formats with graceful fallback
- Proper video/audio format detection

## Build System

### Meson Configuration
- Modern meson build system
- Cross-platform library detection
- Proper dependency management
- PKG-config file generation

### Platform Support
- **macOS**: Uses .dylib from mac/ or mac_arm64/ directories
- **Linux**: Uses .so from linux_x64/ directory  
- **Windows**: Uses .dll from win_x64_vs2017/ directory

## Usage Patterns

### Basic Pipeline
```bash
gst-launch-1.0 sspsrc ip=192.168.1.100 ! h264parse ! avdec_h264 ! autovideosink
```

### Advanced Pipeline
```bash
gst-launch-1.0 sspsrc ip=192.168.1.100 mode=video stream-style=main \
  ! h264parse ! mp4mux ! filesink location=output.mp4
```

### Python Integration
The provided Python example shows how to use the plugin programmatically with proper error handling and event management.

## Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| ip | string | Camera IP address | "192.168.1.100" |
| port | uint | SSP port number | 9999 |
| stream-style | enum | Stream type (default/main/secondary) | default |
| mode | enum | Output mode (video/audio/both) | both |
| buffer-size | uint | Receive buffer size | 0x400000 |
| capability | uint | SSP capability flags | 0 |
| is-hlg | boolean | HLG mode enable | false |

## Error Handling

### Connection Issues
- Graceful handling of connection failures
- Automatic reconnection capabilities (can be extended)
- Proper error reporting through GStreamer messages

### Stream Issues
- Buffer overflow protection
- Format negotiation failure handling
- Timestamp discontinuity management

## Extension Points

### Adding New Formats
1. Update encoder constants in gstsspsrc.cpp
2. Add caps handling in metadata callback
3. Update static pad templates if needed

### Advanced Features
- Stream statistics and monitoring
- Custom pad configurations
- Advanced error recovery
- Quality adaptation

## Testing

### Plugin Verification
```bash
export GST_PLUGIN_PATH=/path/to/build/src
gst-inspect-1.0 sspsrc
```

### Debug Output
```bash
export GST_DEBUG=sspsrc:5
gst-launch-1.0 sspsrc ip=... ! ...
```

### Performance Testing
- Monitor buffer queue levels
- Check for dropped frames/samples
- Measure latency and throughput

## Known Limitations

1. **Combined Mode**: Current implementation doesn't properly handle demuxing video+audio in single pipeline
2. **Reconnection**: No automatic reconnection on network failures
3. **Statistics**: No built-in performance monitoring
4. **Stream Discovery**: No automatic stream format detection

## Future Enhancements

1. **Demuxer Element**: Separate demuxer for proper video+audio handling
2. **Auto-reconnect**: Network failure recovery
3. **Statistics**: Performance monitoring and reporting
4. **Discovery**: Dynamic stream capability detection
5. **Multiple Streams**: Support for multiple concurrent connections

## Troubleshooting

### Common Issues

1. **Plugin not found**: Check GST_PLUGIN_PATH or installation
2. **Connection refused**: Verify IP/port and network connectivity
3. **No caps negotiation**: Check for metadata callback reception
4. **Memory leaks**: Verify proper buffer reference management

### Debug Steps

1. Use gst-inspect-1.0 to verify plugin loading
2. Enable debug output with GST_DEBUG
3. Check network connectivity with ping/telnet
4. Verify camera SSP configuration
5. Test with simplified pipelines first

This implementation provides a solid foundation for SSP integration with GStreamer and can be extended based on specific requirements.
