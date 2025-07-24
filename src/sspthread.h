#ifndef __SSP_THREAD_H__
#define __SSP_THREAD_H__

#include <glib.h>
#include <memory>
#include <string>
#include <functional>

#include "imf/net/threadloop.h"
#include "imf/ssp/sspclient.h"

G_BEGIN_DECLS

// GStreamer-friendly data structures
struct SspVideoData {
    guint8* data;
    gsize len;
    guint64 pts;
    guint64 ntp_timestamp;
    guint32 frm_no;
    guint32 type;
    guint32 codec_type;  // Added to identify H.264 vs H.265
};

struct SspAudioData {
    guint8* data;
    gsize len;
    guint64 pts;
    guint64 ntp_timestamp;
};

struct SspVideoMeta {
    guint32 width;
    guint32 height;
    guint32 timescale;
    guint32 unit;
    guint32 gop;
    guint32 encoder;
};

struct SspAudioMeta {
    guint32 timescale;
    guint32 unit;
    guint32 sample_rate;
    guint32 sample_size;
    guint32 channel;
    guint32 bitrate;
    guint32 encoder;
};

struct SspMeta {
    gboolean pts_is_wall_clock;
    gboolean tc_drop_frame;
    guint32 timecode;
};

// Callback function types
typedef void (*SspVideoCallback) (SspVideoData data, gpointer user_data);
typedef void (*SspAudioCallback) (SspAudioData data, gpointer user_data);
typedef void (*SspMetaCallback) (SspVideoMeta video_meta, SspAudioMeta audio_meta, SspMeta meta, gpointer user_data);
typedef void (*SspConnectedCallback) (gpointer user_data);
typedef void (*SspDisconnectedCallback) (gpointer user_data);
typedef void (*SspExceptionCallback) (gint code, const gchar* description, gpointer user_data);

G_END_DECLS

// C++ wrapper class for libssp
class SspThread {
public:
    SspThread();
    ~SspThread();

    gboolean start(const std::string& ip, guint16 port = 9999, guint32 stream_style = 0);
    void stop();

    void set_video_callback(SspVideoCallback callback, gpointer user_data);
    void set_audio_callback(SspAudioCallback callback, gpointer user_data);
    void set_meta_callback(SspMetaCallback callback, gpointer user_data);
    void set_connected_callback(SspConnectedCallback callback, gpointer user_data);
    void set_disconnected_callback(SspDisconnectedCallback callback, gpointer user_data);
    void set_exception_callback(SspExceptionCallback callback, gpointer user_data);

private:
    void setup_client(imf::Loop* loop);
    void on_video_data(struct imf::SspH264Data* h264);
    void on_audio_data(struct imf::SspAudioData* audio);
    void on_meta_data(struct imf::SspVideoMeta* video_meta, struct imf::SspAudioMeta* audio_meta, struct imf::SspMeta* meta);
    void on_connected();
    void on_disconnected();
    void on_exception(int code, const char* description);

    std::unique_ptr<imf::ThreadLoop> thread_loop_;
    imf::SspClient* client_;
    std::string ip_;
    guint16 port_;
    guint32 stream_style_;
    gboolean running_;

    // Callbacks
    SspVideoCallback video_callback_;
    SspAudioCallback audio_callback_;
    SspMetaCallback meta_callback_;
    SspConnectedCallback connected_callback_;
    SspDisconnectedCallback disconnected_callback_;
    SspExceptionCallback exception_callback_;
    gpointer user_data_;
};

#endif /* __SSP_THREAD_H__ */
