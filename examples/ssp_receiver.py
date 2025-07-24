#!/usr/bin/env python3
"""
GStreamer SSP Plugin Python Example

This example demonstrates how to use the SSP plugin from Python
to receive video/audio streams from Z CAM cameras.
"""

import gi
gi.require_version('Gst', '1.0')
gi.require_version('GstVideo', '1.0')
from gi.repository import Gst, GLib, GstVideo
import sys
import signal
import argparse


class SspReceiver:
    def __init__(self, camera_ip, port=9999, mode='both'):
        self.camera_ip = camera_ip
        self.port = port
        self.mode = mode
        self.codec = 'auto'  # Default to auto-detection
        self.pipeline = None
        self.loop = None
        
        # Initialize GStreamer
        Gst.init(None)
        
        # Create main loop
        self.loop = GLib.MainLoop()
        
        # Handle Ctrl+C gracefully
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, sig, frame):
        print("\nShutting down...")
        self.stop()
        sys.exit(0)
    
    def on_message(self, bus, message):
        """Handle GStreamer bus messages"""
        t = message.type
        
        if t == Gst.MessageType.EOS:
            print("End of stream")
            self.loop.quit()
        elif t == Gst.MessageType.ERROR:
            err, debug = message.parse_error()
            print(f"Error: {err}, {debug}")
            self.loop.quit()
        elif t == Gst.MessageType.WARNING:
            warn, debug = message.parse_warning()
            print(f"Warning: {warn}, {debug}")
        elif t == Gst.MessageType.INFO:
            info, debug = message.parse_info()
            print(f"Info: {info}")
        
        return True
    
    def create_video_pipeline(self):
        """Create video-only pipeline with auto-detection"""
        pipeline_str = (
            f"sspsrc ip={self.camera_ip} port={self.port} mode=video name=src ! "
            "queue ! decodebin ! videoconvert ! "
            "videoscale ! video/x-raw,width=640,height=480 ! "
            "autovideosink"
        )
        return pipeline_str
    
    def create_video_pipeline_h264(self):
        """Create H.264 specific pipeline"""
        pipeline_str = (
            f"sspsrc ip={self.camera_ip} port={self.port} mode=video name=src ! "
            "h264parse ! avdec_h264 ! videoconvert ! "
            "videoscale ! video/x-raw,width=640,height=480 ! "
            "autovideosink"
        )
        return pipeline_str
        
    def create_video_pipeline_h265(self):
        """Create H.265 specific pipeline"""
        pipeline_str = (
            f"sspsrc ip={self.camera_ip} port={self.port} mode=video name=src ! "
            "h265parse ! avdec_h265 ! videoconvert ! "
            "videoscale ! video/x-raw,width=640,height=480 ! "
            "autovideosink"
        )
        return pipeline_str
    
    def create_audio_pipeline(self):
        """Create audio-only pipeline"""
        pipeline_str = (
            f"sspsrc ip={self.camera_ip} port={self.port} mode=audio name=src ! "
            "aacparse ! avdec_aac ! audioconvert ! "
            "autoaudiosink"
        )
        return pipeline_str
    
    def create_recording_pipeline(self, output_file):
        """Create pipeline for recording to file"""
        if self.mode == 'video':
            # Use auto-detection for recording
            pipeline_str = (
                f"sspsrc ip={self.camera_ip} port={self.port} mode=video ! "
                f"queue ! decodebin ! videoconvert ! x264enc ! mp4mux ! "
                f"filesink location={output_file}"
            )
        elif self.mode == 'audio':
            pipeline_str = (
                f"sspsrc ip={self.camera_ip} port={self.port} mode=audio ! "
                f"aacparse ! filesink location={output_file}"
            )
        else:
            # For 'both' mode, we'd need a more complex pipeline
            # This is a simplified version
            pipeline_str = (
                f"sspsrc ip={self.camera_ip} port={self.port} mode=video ! "
                f"queue ! decodebin ! videoconvert ! x264enc ! mp4mux ! "
                f"filesink location={output_file}"
            )
        
        return pipeline_str
    
    def start_preview(self):
        """Start live preview"""
        print(f"Starting {self.mode} preview from {self.camera_ip}:{self.port} (codec: {self.codec})")
        
        if self.mode == 'video':
            if self.codec == 'h264':
                pipeline_str = self.create_video_pipeline_h264()
            elif self.codec == 'h265':
                pipeline_str = self.create_video_pipeline_h265()
            else:  # auto
                pipeline_str = self.create_video_pipeline()
        elif self.mode == 'audio':
            pipeline_str = self.create_audio_pipeline()
        else:
            print("Combined video+audio preview not implemented in this example")
            return False
        
        print(f"Pipeline: {pipeline_str}")
        
        try:
            self.pipeline = Gst.parse_launch(pipeline_str)
        except Exception as e:
            print(f"Failed to create pipeline: {e}")
            return False
        
        # Set up bus
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect("message", self.on_message)
        
        # Start pipeline
        ret = self.pipeline.set_state(Gst.State.PLAYING)
        if ret == Gst.StateChangeReturn.FAILURE:
            print("Failed to start pipeline")
            return False
        
        print("Pipeline started. Press Ctrl+C to stop.")
        
        try:
            self.loop.run()
        except KeyboardInterrupt:
            self.stop()
        
        return True
    
    def start_recording(self, output_file):
        """Start recording to file"""
        print(f"Recording {self.mode} from {self.camera_ip}:{self.port} to {output_file}")
        
        pipeline_str = self.create_recording_pipeline(output_file)
        print(f"Pipeline: {pipeline_str}")
        
        try:
            self.pipeline = Gst.parse_launch(pipeline_str)
        except Exception as e:
            print(f"Failed to create pipeline: {e}")
            return False
        
        # Set up bus
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect("message", self.on_message)
        
        # Start pipeline
        ret = self.pipeline.set_state(Gst.State.PLAYING)
        if ret == Gst.StateChangeReturn.FAILURE:
            print("Failed to start pipeline")
            return False
        
        print("Recording started. Press Ctrl+C to stop.")
        
        try:
            self.loop.run()
        except KeyboardInterrupt:
            self.stop()
        
        return True
    
    def stop(self):
        """Stop the pipeline"""
        if self.pipeline:
            self.pipeline.set_state(Gst.State.NULL)
            self.pipeline = None
        
        if self.loop and self.loop.is_running():
            self.loop.quit()


def main():
    parser = argparse.ArgumentParser(description='GStreamer SSP Plugin Python Example')
    parser.add_argument('--ip', required=True, help='Camera IP address')
    parser.add_argument('--port', type=int, default=9999, help='Camera port (default: 9999)')
    parser.add_argument('--mode', choices=['video', 'audio', 'both'], default='video',
                       help='Stream mode (default: video)')
    parser.add_argument('--codec', choices=['auto', 'h264', 'h265'], default='auto',
                       help='Video codec (default: auto-detect)')
    parser.add_argument('--record', help='Record to file instead of preview')
    
    args = parser.parse_args()
    
    receiver = SspReceiver(args.ip, args.port, args.mode)
    receiver.codec = args.codec
    
    if args.record:
        success = receiver.start_recording(args.record)
    else:
        success = receiver.start_preview()
    
    if not success:
        print("Failed to start receiver")
        sys.exit(1)


if __name__ == '__main__':
    main()
