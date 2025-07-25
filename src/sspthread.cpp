#include "sspthread.h"
#include <gst/gst.h>

SspThread::SspThread()
    : thread_loop_(nullptr)
    , client_(nullptr)
    , running_(false)
{
}

SspThread::~SspThread()
{
    stop();
}

gboolean
SspThread::start(const std::string& ip, guint16 port, guint32 stream_style)
{
    if (running_) {
        GST_WARNING("SSP thread already running");
        return FALSE;
    }

    ip_ = ip;
    port_ = port;
    stream_style_ = stream_style;

    try {
        thread_loop_.reset(new imf::ThreadLoop(std::bind(&SspThread::setup_client, this, std::placeholders::_1)));
        thread_loop_->start();
        running_ = true;
        return TRUE;
    } catch (const std::exception& e) {
        GST_ERROR("Failed to start SSP thread: %s", e.what());
        return FALSE;
    }
}

void
SspThread::stop()
{
    if (!running_) {
        return;
    }

    running_ = false;

    if (client_) {
        client_->stop();
        delete client_;
        client_ = nullptr;
    }

    if (thread_loop_) {
        thread_loop_->stop();
        thread_loop_.reset();
    }
}

void
SspThread::setup_client(imf::Loop* loop)
{
    try {
        // Use larger buffer size like ezdump (4MB instead of 4MB)
        client_ = new imf::SspClient(ip_, loop, 4 * 1024 * 1024, port_, stream_style_);
        
        if (client_->init() != 0) {
            GST_ERROR("Failed to initialize SSP client");
            return;
        }

        // Set up callbacks in the same order as ezdump
        client_->setOnH264DataCallback(std::bind(&SspThread::on_video_data, this, std::placeholders::_1));
        client_->setOnMetaCallback(std::bind(&SspThread::on_meta_data, this, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3));
        client_->setOnDisconnectedCallback(std::bind(&SspThread::on_disconnected, this));
        client_->setOnAudioDataCallback(std::bind(&SspThread::on_audio_data, this, std::placeholders::_1));
        client_->setOnExceptionCallback(std::bind(&SspThread::on_exception, this, std::placeholders::_1, std::placeholders::_2));
        client_->setOnRecvBufferFullCallback(std::bind(&SspThread::on_recv_buffer_full, this));
        client_->setOnConnectionConnectedCallback(std::bind(&SspThread::on_connected, this));

        if (client_->start() != 0) {
            GST_ERROR("Failed to start SSP client");
            return;
        }

        GST_INFO("SSP client started successfully with 4MB buffer");
    } catch (const std::exception& e) {
        GST_ERROR("Exception in SSP client setup: %s", e.what());
    }
}

void
SspThread::on_video_data(struct imf::SspH264Data* h264)
{
    GST_DEBUG("SSP thread received video data: size=%zu, frm_no=%u, type=%u, pts=%" G_GUINT64_FORMAT, 
              h264->len, h264->frm_no, h264->type, h264->pts);
              
    if (!video_callback_) {
        GST_WARNING("No video callback set, dropping frame");
        return;
    }

    // Create a copy of the data since the callback requires it
    guint8* data_copy = (guint8*)g_malloc(h264->len);
    memcpy(data_copy, h264->data, h264->len);

    // Detect codec type from stream data if not already known
    guint32 codec_type = 0;
    if (h264->len >= 4) {
        // Look for NAL unit start codes to determine codec type
        // H.264: NAL unit type in bits 0-4 of first byte after start code
        // H.265: NAL unit type in bits 1-6 of first byte after start code
        
        // Find start code (0x00000001 or 0x000001)
        guint8* nal_start = nullptr;
        for (size_t i = 0; i < h264->len - 4; i++) {
            if (h264->data[i] == 0x00 && h264->data[i+1] == 0x00) {
                if (h264->data[i+2] == 0x00 && h264->data[i+3] == 0x01) {
                    nal_start = &h264->data[i+4];
                    break;
                } else if (h264->data[i+2] == 0x01) {
                    nal_start = &h264->data[i+3];
                    break;
                }
            }
        }
        
        if (nal_start && (nal_start - h264->data) < (long)h264->len) {
            guint8 nal_byte = *nal_start;
            
            // H.265 detection: NAL unit type is in bits 1-6
            guint8 h265_nal_type = (nal_byte >> 1) & 0x3F;
            if (h265_nal_type >= 32 && h265_nal_type <= 40) {
                // H.265 VPS, SPS, PPS, or other H.265-specific NAL types
                codec_type = 265; // VIDEO_ENCODER_H265
            } else {
                // Assume H.264 for other cases
                codec_type = 96;  // VIDEO_ENCODER_H264
            }
        }
    }

    SspVideoData video_data = {
        .data = data_copy,
        .len = h264->len,
        .pts = h264->pts,
        .ntp_timestamp = h264->ntp_timestamp,
        .frm_no = h264->frm_no,
        .type = h264->type,
        .codec_type = codec_type
    };

    video_callback_(video_data, user_data_);
}

void
SspThread::on_audio_data(struct imf::SspAudioData* audio)
{
    if (!audio_callback_) {
        return;
    }

    // Create a copy of the data since the callback requires it
    guint8* data_copy = (guint8*)g_malloc(audio->len);
    memcpy(data_copy, audio->data, audio->len);

    SspAudioData audio_data = {
        .data = data_copy,
        .len = audio->len,
        .pts = audio->pts,
        .ntp_timestamp = audio->ntp_timestamp
    };

    audio_callback_(audio_data, user_data_);
}

void
SspThread::on_meta_data(struct imf::SspVideoMeta* video_meta, 
                       struct imf::SspAudioMeta* audio_meta, 
                       struct imf::SspMeta* meta)
{
    if (!meta_callback_) {
        return;
    }

    SspVideoMeta v_meta = {
        .width = video_meta->width,
        .height = video_meta->height,
        .timescale = video_meta->timescale,
        .unit = video_meta->unit,
        .gop = video_meta->gop,
        .encoder = video_meta->encoder
    };

    SspAudioMeta a_meta = {
        .timescale = audio_meta->timescale,
        .unit = audio_meta->unit,
        .sample_rate = audio_meta->sample_rate,
        .sample_size = audio_meta->sample_size,
        .channel = audio_meta->channel,
        .bitrate = audio_meta->bitrate,
        .encoder = audio_meta->encoder
    };

    SspMeta m_meta = {
        .pts_is_wall_clock = meta->pts_is_wall_clock,
        .tc_drop_frame = meta->tc_drop_frame,
        .timecode = meta->timecode
    };

    meta_callback_(v_meta, a_meta, m_meta, user_data_);
}

void
SspThread::on_connected()
{
    GST_INFO("SSP client connected");
    if (connected_callback_) {
        connected_callback_(user_data_);
    }
}

void
SspThread::on_disconnected()
{
    GST_WARNING("SSP client disconnected");
    if (disconnected_callback_) {
        disconnected_callback_(user_data_);
    }
}

void
SspThread::on_recv_buffer_full()
{
    GST_WARNING("SSP client receive buffer full - may cause frame drops");
}

void
SspThread::on_exception(int code, const char* description)
{
    GST_ERROR("SSP client exception: code=%d, description=%s", code, description);
    if (exception_callback_) {
        exception_callback_(code, description, user_data_);
    }
}

void
SspThread::set_video_callback(SspVideoCallback callback, gpointer user_data)
{
    video_callback_ = callback;
    user_data_ = user_data;
}

void
SspThread::set_audio_callback(SspAudioCallback callback, gpointer user_data)
{
    audio_callback_ = callback;
    user_data_ = user_data;
}

void
SspThread::set_meta_callback(SspMetaCallback callback, gpointer user_data)
{
    meta_callback_ = callback;
    user_data_ = user_data;
}

void
SspThread::set_connected_callback(SspConnectedCallback callback, gpointer user_data)
{
    connected_callback_ = callback;
    user_data_ = user_data;
}

void
SspThread::set_disconnected_callback(SspDisconnectedCallback callback, gpointer user_data)
{
    disconnected_callback_ = callback;
    user_data_ = user_data;
}

void
SspThread::set_exception_callback(SspExceptionCallback callback, gpointer user_data)
{
    exception_callback_ = callback;
    user_data_ = user_data;
}
