#!/bin/bash

# Video Analysis Script - Extract all video settings and GOP information
# Based on checkgob.sh but with comprehensive analysis

if [ -z "$1" ]; then
  echo "Usage: $0 video_file.mp4 [output_format]"
  echo "  output_format: brief (default), detailed, json"
  exit 1
fi

VIDEO="$1"
OUTPUT_FORMAT="${2:-brief}"

if [ ! -f "$VIDEO" ]; then
  echo "Error: File '$VIDEO' not found"
  exit 1
fi

echo "========================================"
echo "Video Analysis Report: $(basename "$VIDEO")"
echo "========================================"

# Extract basic video information
echo "1. BASIC VIDEO INFORMATION"
echo "----------------------------------------"

# Get video stream information using key=value format for better parsing
width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$VIDEO" 2>/dev/null)
height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO" 2>/dev/null)
r_frame_rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$VIDEO" 2>/dev/null)
avg_frame_rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$VIDEO" 2>/dev/null)
codec_name=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$VIDEO" 2>/dev/null)
codec_long_name=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_long_name -of csv=p=0 "$VIDEO" 2>/dev/null)
bit_rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$VIDEO" 2>/dev/null)
pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$VIDEO" 2>/dev/null)
color_space=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of csv=p=0 "$VIDEO" 2>/dev/null)
color_primaries=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries -of csv=p=0 "$VIDEO" 2>/dev/null)
color_transfer=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of csv=p=0 "$VIDEO" 2>/dev/null)
profile=$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of csv=p=0 "$VIDEO" 2>/dev/null)
level=$(ffprobe -v error -select_streams v:0 -show_entries stream=level -of csv=p=0 "$VIDEO" 2>/dev/null)

if [ -z "$width" ] || [ -z "$height" ]; then
  echo "Error: Unable to read video information"
  exit 1
fi

# Calculate FPS from frame rate
if [ -n "$r_frame_rate" ] && [ "$r_frame_rate" != "0/0" ] && [ "$r_frame_rate" != "N/A" ]; then
  fps=$(echo "scale=3; $r_frame_rate" | bc -l 2>/dev/null)
elif [ -n "$avg_frame_rate" ] && [ "$avg_frame_rate" != "0/0" ] && [ "$avg_frame_rate" != "N/A" ]; then
  fps=$(echo "scale=3; $avg_frame_rate" | bc -l 2>/dev/null)
else
  fps="Unknown"
fi

echo "Resolution: ${width}x${height}"
echo "FPS: $fps"
if [ -n "$r_frame_rate" ] && [ "$r_frame_rate" != "N/A" ]; then
  echo "Frame Rate: $r_frame_rate"
fi
echo "Codec: $codec_name"
if [ -n "$codec_long_name" ] && [ "$codec_long_name" != "N/A" ]; then
  echo "Codec Long Name: $codec_long_name"
fi
echo "Pixel Format: $pix_fmt"

# Calculate bitrate in Mbps if available
if [ -n "$bit_rate" ] && [ "$bit_rate" != "N/A" ]; then
    bitrate_mbps=$(echo "scale=2; $bit_rate / 1000000" | bc 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$bitrate_mbps" ]; then
        echo "Bit Rate: ${bitrate_mbps} Mbps"
    else
        echo "Bit Rate: ${bit_rate} bps"
    fi
else
    echo "Bit Rate: N/A"
fi
if [ -n "$profile" ] && [ "$profile" != "N/A" ]; then
  echo "Profile: $profile"
fi
if [ -n "$level" ] && [ "$level" != "N/A" ]; then
  echo "Level: $level"
fi

# Color information
if [ -n "$color_space" ] && [ "$color_space" != "N/A" ]; then
  echo "Color Space: $color_space"
fi
if [ -n "$color_primaries" ] && [ "$color_primaries" != "N/A" ]; then
  echo "Color Primaries: $color_primaries"
fi
if [ -n "$color_transfer" ] && [ "$color_transfer" != "N/A" ]; then
  echo "Color Transfer: $color_transfer"
fi

echo ""

# Get format information
echo "2. CONTAINER/FORMAT INFORMATION"
echo "----------------------------------------"
format_name=$(ffprobe -v error -show_entries format=format_name -of csv=p=0 "$VIDEO" 2>/dev/null)
format_long_name=$(ffprobe -v error -show_entries format=format_long_name -of csv=p=0 "$VIDEO" 2>/dev/null)
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null)
size=$(ffprobe -v error -show_entries format=size -of csv=p=0 "$VIDEO" 2>/dev/null)
format_bit_rate=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$VIDEO" 2>/dev/null)

echo "Format: $format_name"
if [ -n "$format_long_name" ] && [ "$format_long_name" != "N/A" ]; then
  echo "Format Long Name: $format_long_name"
fi
if [ -n "$duration" ] && [ "$duration" != "N/A" ]; then
  duration_formatted=$(echo "scale=3; $duration" | bc -l 2>/dev/null)
  echo "Duration: ${duration_formatted} seconds"
fi
if [ -n "$size" ] && [ "$size" != "N/A" ]; then
  size_mb=$(echo "scale=2; $size/1024/1024" | bc -l 2>/dev/null)
  echo "File Size: $size bytes (${size_mb} MB)"
fi
if [ -n "$format_bit_rate" ] && [ "$format_bit_rate" != "N/A" ]; then
  echo "Overall Bit Rate: $format_bit_rate bps"
fi

echo ""

# GOP Analysis
echo "3. GOP (Group of Pictures) ANALYSIS"
echo "----------------------------------------"

# Count total frames first
total_frames=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$VIDEO" 2>/dev/null)

if [ "$OUTPUT_FORMAT" = "brief" ]; then
  echo "Total Frames: $total_frames"
  echo "Analyzing GOP structure..."
  
  # Quick GOP analysis - show only keyframes
  gop_output=$(ffprobe -v error -select_streams v:0 -show_frames \
    -show_entries frame=pkt_pts_time,pict_type,key_frame "$VIDEO" 2>/dev/null | \
    awk -v total="$total_frames" '
    BEGIN { 
      frame = 0; 
      prev_keyframe = -1;
      keyframes = 0;
      gop_sizes = "";
      min_gop = 999999;
      max_gop = 0;
      sum_gop = 0;
      gop_count = 0;
      current_time = 0;
      current_keyframe = 0;
      current_pict_type = "";
    }
    /^\[FRAME\]/ {
      frame++;
      current_keyframe = 0;
      current_pict_type = "";
      current_time = 0;
    }
    /^key_frame=/ {
      current_keyframe = substr($0, 11);
    }
    /^pict_type=/ {
      current_pict_type = substr($0, 12);
    }
    /^pkt_pts_time=/ {
      current_time = substr($0, 14);
    }
    /^\[\/FRAME\]/ {
      if (current_keyframe == 1) {
        keyframes++;
        if (prev_keyframe >= 0) {
          gop_size = frame - prev_keyframe;
          gop_sizes = gop_sizes gop_size " ";
          if (gop_size < min_gop) min_gop = gop_size;
          if (gop_size > max_gop) max_gop = gop_size;
          sum_gop += gop_size;
          gop_count++;
        }
        prev_keyframe = frame;
        printf "Keyframe #%d at frame %d (t=%.3fs) [%s]\n", keyframes, frame, current_time, current_pict_type;
      }
    }
    END {
      if (gop_count > 0) {
        printf "\nGOP Statistics:\n";
        printf "  Total Keyframes: %d\n", keyframes;
        printf "  Average GOP Size: %.1f frames\n", sum_gop / gop_count;
        printf "  Min GOP Size: %d frames\n", min_gop;
        printf "  Max GOP Size: %d frames\n", max_gop;
        printf "  GOP Sizes: %s\n", gop_sizes;
      } else if (keyframes > 0) {
        printf "Total Keyframes: %d\n", keyframes;
        printf "All frames are keyframes (GOP size = 1)\n";
      } else {
        printf "No keyframes detected\n";
      }
    }')
  
  # Display GOP analysis output
  echo "$gop_output"

elif [ "$OUTPUT_FORMAT" = "detailed" ]; then
  echo "Total Frames: $total_frames"
  echo "Detailed frame analysis:"
  echo "Format: [#Frame] [Time] [Type] [Keyframe] [Size]"
  
  ffprobe -v error -select_streams v:0 -show_frames -print_format csv \
    -show_entries frame=pkt_pts_time,pict_type,key_frame,pkt_size "$VIDEO" 2>/dev/null | \
    awk -F',' '
    BEGIN { 
      frame = 0; 
      prev_keyframe = -1;
      i_frames = 0; p_frames = 0; b_frames = 0;
    }
    {
      frame++;
      frame_type = $3;
      is_keyframe = $4;
      size = $5;
      
      if (frame_type == "I") i_frames++;
      else if (frame_type == "P") p_frames++;
      else if (frame_type == "B") b_frames++;
      
      printf "[%d] t=%.3fs type=%s key=%s size=%d bytes\n", frame, $2, frame_type, is_keyframe, size;
      
      if (is_keyframe == 1) {
        if (prev_keyframe >= 0) {
          gop_size = frame - prev_keyframe;
          printf ">>> GOP size: %d frames\n", gop_size;
        }
        prev_keyframe = frame;
      }
    }
    END {
      printf "\nFrame Type Statistics:\n";
      printf "  I-frames: %d\n", i_frames;
      printf "  P-frames: %d\n", p_frames;
      printf "  B-frames: %d\n", b_frames;
    }'

elif [ "$OUTPUT_FORMAT" = "json" ]; then
  # JSON output format
  
  # Calculate bitrate in Mbps for JSON output
  if [ -n "$bit_rate" ] && [ "$bit_rate" != "N/A" ]; then
    bitrate_mbps=$(echo "scale=2; $bit_rate / 1000000" | bc 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$bitrate_mbps" ]; then
      bitrate_json="$bitrate_mbps"
    else
      bitrate_json="null"
    fi
  else
    bitrate_json="null"
  fi
  
  echo "{"
  echo "  \"file\": \"$(basename "$VIDEO")\","
  echo "  \"video\": {"
  echo "    \"width\": $width,"
  echo "    \"height\": $height,"
  echo "    \"fps\": \"$fps\","
  echo "    \"frame_rate\": \"$r_frame_rate\","
  echo "    \"codec\": \"$codec_name\","
  echo "    \"codec_long_name\": \"$codec_long_name\","
  echo "    \"pixel_format\": \"$pix_fmt\","
  echo "    \"bit_rate_bps\": \"$bit_rate\","
  echo "    \"bit_rate_mbps\": $bitrate_json,"
  echo "    \"profile\": \"$profile\","
  echo "    \"level\": \"$level\","
  echo "    \"color_space\": \"$color_space\","
  echo "    \"color_primaries\": \"$color_primaries\","
  echo "    \"color_transfer\": \"$color_transfer\""
  echo "  },"
  echo "  \"format\": {"
  echo "    \"format_name\": \"$format_name\","
  echo "    \"format_long_name\": \"$format_long_name\","
  echo "    \"duration\": \"$duration\","
  echo "    \"size\": \"$size\","
  echo "    \"bit_rate\": \"$format_bit_rate\""
  echo "  },"
  echo "  \"frames\": {"
  echo "    \"total\": $total_frames"
  echo "  },"
  
  # GOP analysis for JSON
  ffprobe -v error -select_streams v:0 -show_frames -print_format csv \
    -show_entries frame=pkt_pts_time,pict_type,key_frame "$VIDEO" 2>/dev/null | \
    awk -F',' '
    BEGIN { 
      frame = 0; 
      prev_keyframe = -1;
      keyframes = 0;
      min_gop = 999999;
      max_gop = 0;
      sum_gop = 0;
      gop_count = 0;
      i_frames = 0; p_frames = 0; b_frames = 0;
    }
    {
      frame++;
      frame_type = $3;
      if (frame_type == "I") i_frames++;
      else if (frame_type == "P") p_frames++;
      else if (frame_type == "B") b_frames++;
      
      if ($4 == 1) {
        keyframes++;
        if (prev_keyframe >= 0) {
          gop_size = frame - prev_keyframe;
          if (gop_size < min_gop) min_gop = gop_size;
          if (gop_size > max_gop) max_gop = gop_size;
          sum_gop += gop_size;
          gop_count++;
        }
        prev_keyframe = frame;
      }
    }
    END {
      printf "  \"gop\": {\n";
      printf "    \"keyframes\": %d,\n", keyframes;
      if (gop_count > 0) {
        avg_gop = sum_gop / gop_count;
        printf "    \"average_size\": %.1f,\n", avg_gop;
        printf "    \"min_size\": %d,\n", min_gop;
        printf "    \"max_size\": %d\n", max_gop;
      } else {
        printf "    \"average_size\": 0,\n";
        printf "    \"min_size\": 0,\n";
        printf "    \"max_size\": 0\n";
      }
      printf "  },\n";
      printf "  \"frame_types\": {\n";
      printf "    \"i_frames\": %d,\n", i_frames;
      printf "    \"p_frames\": %d,\n", p_frames;
      printf "    \"b_frames\": %d\n", b_frames;
      printf "  }\n";
    }'
  
  echo "}"
fi

echo ""
echo "4. ADDITIONAL METADATA"
echo "----------------------------------------"

# Check for additional metadata
METADATA=$(ffprobe -v error -show_entries format_tags -of csv=p=0 "$VIDEO" 2>/dev/null)
if [ -n "$METADATA" ]; then
  echo "Metadata found:"
  echo "$METADATA"
else
  echo "No additional metadata found"
fi

echo ""
echo "========================================"
echo "Analysis completed for: $(basename "$VIDEO")"
echo "========================================"
