# REST API Endpoints Used in ZDump Solution

This document lists all REST API endpoints found in the ZDump codebase used for camera control and streaming.

## Camera Information & Status

### Get Camera Information
```
GET /info
```
- Used to get camera information (model, firmware version, MAC address, IP, serial number)
- Can be used as a "ping" to check if camera is available

### Get Camera Status
```
GET /camera_status
```
- Used to check camera status including ezlink synchronization status
- Returns `sync_link` field for ezlink status validation

## Session Management

### Check Session Status
```
GET /ctrl/session
```
- Check current session status

### Quit Session
```
GET /ctrl/session?action=quit
```
- Quit the current session

### Occupy Session
```
GET /ctrl/session?action=occupy
```
- Occupy session to prevent other clients from controlling the camera

## Working Mode Control

### Exit Standby Mode
```
GET /ctrl/mode?action=exit_standby
```
- Exit standby mode and activate camera controls

### Switch to Video Recording Mode
```
GET /ctrl/mode?action=to_rec
```
- Switch camera to video recording mode

### Switch to Playback Mode
```
GET /ctrl/mode?action=to_pb
```
- Switch camera to playback mode

### Switch to Standby
```
GET /ctrl/mode?action=to_standby
```
- Switch camera to standby mode

### Query Working Mode
```
GET /ctrl/mode?action=query
```
- Query current working mode

## Camera Settings - Get Parameters

### Get Setting Value
```
GET /ctrl/get?k={key}
```
- Get current value of any camera setting
- Common keys: `iso`, `movfmt`, `movvfr`, `ezlink_mode`, `wb`, `focus`, etc.

## Camera Settings - Set Parameters

### Set EZLink Mode
```
GET /ctrl/set?ezlink_mode=Master
GET /ctrl/set?ezlink_mode=Slave
```
- Configure camera as master or slave for multi-camera synchronization

### Set Movie Format
```
GET /ctrl/set?movfmt={format}
```
- Set recording format (e.g., `4KP30`, `1080P25`, `4KP60`)

### Set Variable Frame Rate
```
GET /ctrl/set?movvfr=Off
GET /ctrl/set?movvfr=120
```
- Enable/disable variable frame rate or set VFR value

### Set Shutter Speed/Time
```
GET /ctrl/set?shutter_time={value}
```
- Set shutter speed (e.g., `1/100`, `1/50`)

### Set Color Space/LUT
```
GET /ctrl/set?lut={value}
```
- Set color space/look-up table

### Set Iris/Aperture
```
GET /ctrl/set?iris={value}
```
- Set aperture/iris value

### Set ISO
```
GET /ctrl/set?iso={value}
```
- Set ISO sensitivity value

### Set White Balance Mode
```
GET /ctrl/set?wb={mode}
```
- Set white balance mode (e.g., `Manual`, `Auto`, `Expert`)

### Set Manual White Balance Value
```
GET /ctrl/set?mwb={value}
```
- Set manual white balance value in Kelvin

### Set Focus Mode
```
GET /ctrl/set?focus={mode}
```
- Set focus mode (e.g., `AF`, `MF`)

### Set Focus Position
```
GET /ctrl/set?lens_focus_pos={value}
```
- Set manual focus position

## Stream Control

### Set Stream Source
```
GET /ctrl/set?send_stream=Stream0
GET /ctrl/set?send_stream=Stream1
GET /ctrl/set?send_stream=none
```
- Control which stream is sent over network or disable streaming

### Configure Stream Settings
```
GET /ctrl/stream_setting?index={stream}&{parameters}
```
Parameters include:
- `width={pixels}` - Video width
- `height={pixels}` - Video height  
- `fps={value}` - Frames per second
- `venc={codec}` - Video encoder (h264, h265)
- `bitwidth={bits}` - Bit width (8, 10)
- `bitrate={bps}` - Bitrate in bits per second
- `gop_n={frames}` - GOP size in frames

Example:
```
GET /ctrl/stream_setting?index=stream0&width=1920&height=1080&fps=25&venc=h265&bitwidth=8&bitrate=25000000&gop_n=30
```

### Query Stream Settings
```
GET /ctrl/stream_setting?action=query
```
- Query current stream configuration

## Video Recording Control

### Start Recording
```
GET /ctrl/rec?action=start
```
- Start video recording

### Stop Recording
```
GET /ctrl/rec?action=stop
```
- Stop video recording

### Query Remaining Recording Time
```
GET /ctrl/rec?action=remain
```
- Query maximum remaining recording time in minutes

## Date/Time Synchronization

### Set Date and Time
```
GET /datetime?date=YYYY-MM-DD&time=hh:mm:ss
```
- Synchronize camera date and time

### NTP Time Sync
```
GET /ctrl/sntp?action=start&ip_addr={ip}&port=123
GET /ctrl/sntp?action=stop
```
- Start/stop NTP time synchronization

## Network Configuration

### Set Network Mode
```
GET /ctrl/network?action=set&mode=Router
GET /ctrl/network?action=set&mode=Direct
GET /ctrl/network?action=set&mode=Static&ipaddr={ip}&netmask={mask}&gateway={gw}
```
- Configure network settings (Router/DHCP client, Direct/DHCP server, Static IP)

### Query Network Settings
```
GET /ctrl/network?action=query
GET /ctrl/network?action=info
```
- Query current network configuration

## System Control

### Shutdown Camera
```
GET /ctrl/shutdown
```
- Shutdown the camera

### Reboot Camera
```
GET /ctrl/reboot
```
- Reboot the camera

## Focus & Zoom Control

### Auto Focus
```
GET /ctrl/af
```
- Trigger auto focus

### Update AF ROI
```
GET /ctrl/af?action=update_roi&x={x}&y={y}&w={w}&h={h}
GET /ctrl/af?action=update_roi_center&x={x}&y={y}
```
- Update auto focus region of interest

### Query AF ROI
```
GET /ctrl/af?action=query
```
- Query current auto focus ROI

### Manual Focus Drive
```
GET /ctrl/set?mf_drive={value}
```
- Manual focus drive control (values: -3 to 3)

### Zoom Control
```
GET /ctrl/set?lens_zoom=in
GET /ctrl/set?lens_zoom=out
GET /ctrl/set?lens_zoom=stop
GET /ctrl/set?lens_zoom_pos={position}
```
- Control zoom in/out/stop or set specific zoom position

## Preview Control

### Magnify Preview
```
GET /ctrl/mag?action=enable
GET /ctrl/mag?action=disable
GET /ctrl/mag?action=query
```
- Enable/disable/query preview magnification

## Pan-Tilt Control

### Pan-Tilt Direction Control
```
GET /ctrl/pt?action={direction}&speed={N}
```
Directions: `left`, `right`, `up`, `down`, `leftup`, `leftdown`, `rightup`, `rightdown`, `stop`
Speed range: 0-0x3f

## Card Management

### Check Card Presence
```
GET /ctrl/card?action=present
```
- Check if storage card is present

### Format Card
```
GET /ctrl/card?action=format
GET /ctrl/card?action=fat32
GET /ctrl/card?action=exfat
```
- Format storage card (auto-detect, FAT32, or exFAT)

### Query Card Space
```
GET /ctrl/card?action=query_free
GET /ctrl/card?action=query_total
```
- Query free or total storage space

## File Management

### List Directories
```
GET /DCIM/
```
- List directories in DCIM folder

### List Files in Directory
```
GET /DCIM/{folder}/
```
- List files in specific folder

### Download File
```
GET /DCIM/{folder}/{filename}
```
- Download specific file

### Delete File
```
GET /DCIM/{folder}/{filename}?act=rm
```
- Delete specific file

### Get Thumbnail
```
GET /DCIM/{folder}/{filename}?act=thm
```
- Get JPEG thumbnail of file

### Get Screennail
```
GET /DCIM/{folder}/{filename}?act=scr
```
- Get larger JPEG preview of file

### Get File Creation Time
```
GET /DCIM/{folder}/{filename}?act=ct
```
- Get file creation time as Unix timestamp

### Get File Information
```
GET /DCIM/{folder}/{filename}?act=info
```
- Get file information (duration, size, resolution, etc.)

## Advanced Image Controls

### Manual Black Level Control
```
GET /ctrl/manual_blc?action=get
GET /ctrl/manual_blc?action=set&enable={0|1}&rggb={r,gr,gb,b}
```
- Get/set manual black level adjustment

### Manual RGB Gain
```
GET /ctrl/get?k=mwb_r
GET /ctrl/get?k=mwb_b
GET /ctrl/set?mwb_r={value}
GET /ctrl/set?mwb_b={value}
```
- Get/set manual RGB gain values

### Customized Image Profile
```
GET /ctrl/cusomized_image_profile?action=get&option={option}
GET /ctrl/cusomized_image_profile?action=set&option={option}&{parameters}
```
Options: `black_gamma`, `knee`
- Configure advanced image processing options

## Built-in Streaming Services

### MJPEG Stream
```
GET /mjpeg_stream
```
- Access MJPEG over HTTP stream (if supported)

### RTSP Stream
```
rtsp://{ip}/live_stream
```
- RTSP streaming URL

### WebSocket
```
ws://{host}:81
wss://{host}:81
```
- WebSocket connection for real-time communication

## Notes

- All endpoints use HTTP GET method
- Base URL format: `http://{camera_ip}/`
- Most control endpoints require an active session
- Response format is typically JSON with `code`, `desc`, and `msg` fields
- `code: 0` indicates success, `code: 1` indicates error
- Parameters in `{brackets}` should be replaced with actual values
- Query parameters are case-sensitive
