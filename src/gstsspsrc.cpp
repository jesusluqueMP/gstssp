#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "gstsspsrc.h"
#include "sspthread.h"

#include <gst/gst.h>
#include <gst/base/gstpushsrc.h>
#include <gst/video/video.h>
#include <unistd.h>
#include <gst/audio/audio.h>

GST_DEBUG_CATEGORY_STATIC (gst_ssp_src_debug);
#define GST_CAT_DEFAULT gst_ssp_src_debug

/* Filter signals and args */
enum
{
  /* FILL ME */
  LAST_SIGNAL
};

enum
{
  PROP_0,
  PROP_IP,
  PROP_PORT,
  PROP_STREAM_STYLE,
  PROP_MODE,
  PROP_BUFFER_SIZE,
  PROP_CAPABILITY,
  PROP_IS_HLG
};

#define DEFAULT_IP "192.168.1.100"
#define DEFAULT_PORT 9999
#define DEFAULT_STREAM_STYLE GST_SSP_STREAM_DEFAULT
#define DEFAULT_MODE GST_SSP_MODE_BOTH
#define DEFAULT_BUFFER_SIZE 0x400000
#define DEFAULT_CAPABILITY 0
#define DEFAULT_IS_HLG FALSE

/* Use encoder types from libssp */

static GstStaticPadTemplate src_template = GST_STATIC_PAD_TEMPLATE ("src",
    GST_PAD_SRC,
    GST_PAD_ALWAYS,
    GST_STATIC_CAPS ("video/x-h264, stream-format=byte-stream, alignment=nal; "
                     "video/x-h265, stream-format=byte-stream, alignment=nal; "
                     "audio/mpeg, mpegversion=4, stream-format=raw; "
                     "audio/x-raw, format=S16LE, layout=interleaved")
    );

#define gst_ssp_src_parent_class parent_class
G_DEFINE_TYPE (GstSspSrc, gst_ssp_src, GST_TYPE_PUSH_SRC);

static void gst_ssp_src_set_property (GObject * object, guint prop_id,
    const GValue * value, GParamSpec * pspec);
static void gst_ssp_src_get_property (GObject * object, guint prop_id,
    GValue * value, GParamSpec * pspec);
static void gst_ssp_src_finalize (GObject * object);

static gboolean gst_ssp_src_start (GstBaseSrc * basesrc);
static gboolean gst_ssp_src_stop (GstBaseSrc * basesrc);
static GstFlowReturn gst_ssp_src_create (GstPushSrc * psrc, GstBuffer ** buf);
static gboolean gst_ssp_src_unlock (GstBaseSrc * basesrc);
static gboolean gst_ssp_src_unlock_stop (GstBaseSrc * basesrc);
static void gst_ssp_src_get_times (GstBaseSrc * basesrc, GstBuffer * buffer,
    GstClockTime * start, GstClockTime * end);

/* SSP callbacks */
static void on_video_data_cb (SspVideoData data, gpointer user_data);
static void on_audio_data_cb (SspAudioData data, gpointer user_data);
static void on_meta_cb (SspVideoMeta video_meta, SspAudioMeta audio_meta, SspMeta meta, gpointer user_data);
static void on_connected_cb (gpointer user_data);
static void on_disconnected_cb (gpointer user_data);
static void on_exception_cb (gint code, const gchar* description, gpointer user_data);

/* Stream style enum */
#define GST_TYPE_SSP_STREAM_STYLE (gst_ssp_stream_style_get_type ())
static GType
gst_ssp_stream_style_get_type (void)
{
  static GType stream_style_type = 0;
  static const GEnumValue stream_styles[] = {
    {GST_SSP_STREAM_DEFAULT, "Default stream", "default"},
    {GST_SSP_STREAM_MAIN, "Main stream", "main"},
    {GST_SSP_STREAM_SEC, "Secondary stream", "secondary"},
    {0, NULL, NULL}
  };

  if (!stream_style_type) {
    stream_style_type = g_enum_register_static ("GstSspStreamStyle", stream_styles);
  }
  return stream_style_type;
}

/* Mode enum */
#define GST_TYPE_SSP_MODE (gst_ssp_mode_get_type ())
static GType
gst_ssp_mode_get_type (void)
{
  static GType mode_type = 0;
  static const GEnumValue modes[] = {
    {GST_SSP_MODE_VIDEO_ONLY, "Video only", "video"},
    {GST_SSP_MODE_AUDIO_ONLY, "Audio only", "audio"},
    {GST_SSP_MODE_BOTH, "Both video and audio", "both"},
    {0, NULL, NULL}
  };

  if (!mode_type) {
    mode_type = g_enum_register_static ("GstSspMode", modes);
  }
  return mode_type;
}

static void
gst_ssp_src_class_init (GstSspSrcClass * klass)
{
  GObjectClass *gobject_class;
  GstElementClass *gstelement_class;
  GstBaseSrcClass *gstbasesrc_class;
  GstPushSrcClass *gstpushsrc_class;

  gobject_class = (GObjectClass *) klass;
  gstelement_class = (GstElementClass *) klass;
  gstbasesrc_class = (GstBaseSrcClass *) klass;
  gstpushsrc_class = (GstPushSrcClass *) klass;

  gobject_class->set_property = gst_ssp_src_set_property;
  gobject_class->get_property = gst_ssp_src_get_property;
  gobject_class->finalize = gst_ssp_src_finalize;

  g_object_class_install_property (gobject_class, PROP_IP,
      g_param_spec_string ("ip", "IP Address",
          "IP address of the SSP server", DEFAULT_IP,
          (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  g_object_class_install_property (gobject_class, PROP_PORT,
      g_param_spec_uint ("port", "Port",
          "Port of the SSP server", 1, 65535, DEFAULT_PORT,
          (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  g_object_class_install_property (gobject_class, PROP_STREAM_STYLE,
      g_param_spec_enum ("stream-style", "Stream Style",
          "Stream style to request", GST_TYPE_SSP_STREAM_STYLE,
          DEFAULT_STREAM_STYLE, (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  g_object_class_install_property (gobject_class, PROP_MODE,
      g_param_spec_enum ("mode", "Mode",
          "Output mode: video, audio, or both", GST_TYPE_SSP_MODE,
          DEFAULT_MODE, (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  g_object_class_install_property (gobject_class, PROP_BUFFER_SIZE,
      g_param_spec_uint ("buffer-size", "Buffer Size",
          "Receive buffer size", 1024, G_MAXUINT, DEFAULT_BUFFER_SIZE,
          (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  g_object_class_install_property (gobject_class, PROP_CAPABILITY,
      g_param_spec_uint ("capability", "Capability",
          "SSP capability flags", 0, G_MAXUINT32, DEFAULT_CAPABILITY,
          (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  g_object_class_install_property (gobject_class, PROP_IS_HLG,
      g_param_spec_boolean ("is-hlg", "Is HLG",
          "Enable HLG mode", DEFAULT_IS_HLG,
          (GParamFlags)(G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS)));

  gst_element_class_set_static_metadata (gstelement_class,
      "SSP Source",
      "Source/Network",
      "Receive video/audio streams via Simple Stream Protocol (SSP) from Z CAM cameras",
      "Your Name <your.email@example.com>");

  gst_element_class_add_static_pad_template (gstelement_class, &src_template);

  gstbasesrc_class->start = GST_DEBUG_FUNCPTR (gst_ssp_src_start);
  gstbasesrc_class->stop = GST_DEBUG_FUNCPTR (gst_ssp_src_stop);
  gstbasesrc_class->unlock = GST_DEBUG_FUNCPTR (gst_ssp_src_unlock);
  gstbasesrc_class->unlock_stop = GST_DEBUG_FUNCPTR (gst_ssp_src_unlock_stop);
  gstbasesrc_class->get_times = GST_DEBUG_FUNCPTR (gst_ssp_src_get_times);

  gstpushsrc_class->create = GST_DEBUG_FUNCPTR (gst_ssp_src_create);

  GST_DEBUG_CATEGORY_INIT (gst_ssp_src_debug, "sspsrc", 0, "SSP source");
}

static void
gst_ssp_src_init (GstSspSrc * src)
{
  src->ip = g_strdup (DEFAULT_IP);
  src->port = DEFAULT_PORT;
  src->stream_style = DEFAULT_STREAM_STYLE;
  src->mode = DEFAULT_MODE;
  src->buffer_size = DEFAULT_BUFFER_SIZE;
  src->capability = DEFAULT_CAPABILITY;
  src->is_hlg = DEFAULT_IS_HLG;

  src->ssp_thread = NULL;
  src->video_pad = NULL;
  src->audio_pad = NULL;
  src->video_queue = g_async_queue_new ();
  src->audio_queue = g_async_queue_new ();

  src->started = FALSE;
  src->connected = FALSE;
  src->has_video_meta = FALSE;
  src->has_audio_meta = FALSE;
  src->video_caps_set = FALSE;
  src->audio_caps_set = FALSE;

  /* Initialize timestamp tracking */
  src->timestamp = 0;
  src->first_timestamp = GST_CLOCK_TIME_NONE;

  g_mutex_init (&src->lock);
  g_cond_init (&src->cond);

  /* Set live source with proper latency */
  gst_base_src_set_live (GST_BASE_SRC (src), TRUE);
  gst_base_src_set_format (GST_BASE_SRC (src), GST_FORMAT_TIME);
  gst_base_src_set_do_timestamp (GST_BASE_SRC (src), FALSE); /* We handle our own timestamps */
  
  /* Set automatic EOS to prevent infinite latency redistribution */
  gst_base_src_set_automatic_eos (GST_BASE_SRC (src), FALSE);
}

static void
gst_ssp_src_finalize (GObject * object)
{
  GstSspSrc *src = GST_SSP_SRC (object);

  g_free (src->ip);
  g_async_queue_unref (src->video_queue);
  g_async_queue_unref (src->audio_queue);
  g_mutex_clear (&src->lock);
  g_cond_clear (&src->cond);

  G_OBJECT_CLASS (parent_class)->finalize (object);
}

static void
gst_ssp_src_set_property (GObject * object, guint prop_id,
    const GValue * value, GParamSpec * pspec)
{
  GstSspSrc *src = GST_SSP_SRC (object);

  switch (prop_id) {
    case PROP_IP:
      g_free (src->ip);
      src->ip = g_strdup (g_value_get_string (value));
      break;
    case PROP_PORT:
      src->port = g_value_get_uint (value);
      break;
    case PROP_STREAM_STYLE:
      src->stream_style = (GstSspStreamStyle) g_value_get_enum (value);
      break;
    case PROP_MODE:
      src->mode = (GstSspMode) g_value_get_enum (value);
      break;
    case PROP_BUFFER_SIZE:
      src->buffer_size = g_value_get_uint (value);
      break;
    case PROP_CAPABILITY:
      src->capability = g_value_get_uint (value);
      break;
    case PROP_IS_HLG:
      src->is_hlg = g_value_get_boolean (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_ssp_src_get_property (GObject * object, guint prop_id,
    GValue * value, GParamSpec * pspec)
{
  GstSspSrc *src = GST_SSP_SRC (object);

  switch (prop_id) {
    case PROP_IP:
      g_value_set_string (value, src->ip);
      break;
    case PROP_PORT:
      g_value_set_uint (value, src->port);
      break;
    case PROP_STREAM_STYLE:
      g_value_set_enum (value, src->stream_style);
      break;
    case PROP_MODE:
      g_value_set_enum (value, src->mode);
      break;
    case PROP_BUFFER_SIZE:
      g_value_set_uint (value, src->buffer_size);
      break;
    case PROP_CAPABILITY:
      g_value_set_uint (value, src->capability);
      break;
    case PROP_IS_HLG:
      g_value_set_boolean (value, src->is_hlg);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static gboolean
gst_ssp_src_start (GstBaseSrc * basesrc)
{
  GstSspSrc *src = GST_SSP_SRC (basesrc);
  SspThread *ssp_thread;

  GST_DEBUG_OBJECT (src, "Starting SSP source");

  /* Create SSP thread */
  ssp_thread = new SspThread();
  src->ssp_thread = (gpointer) ssp_thread;

  /* Set up callbacks */
  if (src->mode == GST_SSP_MODE_VIDEO_ONLY || src->mode == GST_SSP_MODE_BOTH) {
    ssp_thread->set_video_callback (on_video_data_cb, src);
  }
  if (src->mode == GST_SSP_MODE_AUDIO_ONLY || src->mode == GST_SSP_MODE_BOTH) {
    ssp_thread->set_audio_callback (on_audio_data_cb, src);
  }
  ssp_thread->set_meta_callback (on_meta_cb, src);
  ssp_thread->set_connected_callback (on_connected_cb, src);
  ssp_thread->set_disconnected_callback (on_disconnected_cb, src);
  ssp_thread->set_exception_callback (on_exception_cb, src);

  /* Start the SSP client */
  if (!ssp_thread->start (std::string(src->ip), src->port, src->stream_style)) {
    GST_ERROR_OBJECT (src, "Failed to start SSP thread");
    delete ssp_thread;
    src->ssp_thread = NULL;
    return FALSE;
  }

  src->started = TRUE;
  
  GST_DEBUG_OBJECT (src, "SSP source started successfully");
  return TRUE;
}

static gboolean
gst_ssp_src_stop (GstBaseSrc * basesrc)
{
  GstSspSrc *src = GST_SSP_SRC (basesrc);
  SspThread *ssp_thread = (SspThread *) src->ssp_thread;

  GST_DEBUG_OBJECT (src, "Stopping SSP source");

  if (ssp_thread) {
    ssp_thread->stop ();
    delete ssp_thread;
    src->ssp_thread = NULL;
  }

  /* Clear queues */
  gpointer buffer;
  while ((buffer = g_async_queue_try_pop (src->video_queue)) != NULL) {
    gst_buffer_unref (GST_BUFFER (buffer));
  }
  while ((buffer = g_async_queue_try_pop (src->audio_queue)) != NULL) {
    gst_buffer_unref (GST_BUFFER (buffer));
  }

  src->started = FALSE;
  src->connected = FALSE;
  src->has_video_meta = FALSE;
  src->has_audio_meta = FALSE;
  src->video_caps_set = FALSE;
  src->audio_caps_set = FALSE;
  
  /* Reset timestamp tracking */
  src->timestamp = 0;
  src->first_timestamp = GST_CLOCK_TIME_NONE;

  GST_DEBUG_OBJECT (src, "SSP source stopped");
  return TRUE;
}

static GstFlowReturn
gst_ssp_src_create (GstPushSrc * psrc, GstBuffer ** buf)
{
  GstSspSrc *src = GST_SSP_SRC (psrc);
  GstBuffer *buffer = NULL;

  if (!src->started) {
    return GST_FLOW_ERROR;
  }

  /* Wait for connection if not connected yet */
  g_mutex_lock (&src->lock);
  while (!src->connected && src->started) {
    g_cond_wait (&src->cond, &src->lock);
  }
  g_mutex_unlock (&src->lock);

  if (!src->connected) {
    GST_DEBUG_OBJECT (src, "Not connected, returning error");
    return GST_FLOW_ERROR;
  }

  /* Wait for metadata to be received - but be more tolerant */
  g_mutex_lock (&src->lock);
  int timeout_count = 0;
  while (!src->has_video_meta && !src->has_audio_meta && src->connected && timeout_count < 200) {
    g_mutex_unlock (&src->lock);
    usleep(50000); /* 50ms sleep - longer intervals, more patience */
    timeout_count++;
    g_mutex_lock (&src->lock);
  }
  g_mutex_unlock (&src->lock);

  /* If still no metadata but we're connected, try to continue anyway */
  if (!src->has_video_meta && !src->has_audio_meta) {
    if (!src->connected) {
      GST_DEBUG_OBJECT (src, "Disconnected while waiting for metadata");
      return GST_FLOW_ERROR;
    }
    GST_DEBUG_OBJECT (src, "No metadata received yet but connected, trying to get data anyway");
    /* Don't return GST_FLOW_NOT_LINKED immediately - try to get data */
  }

  /* Get buffer from appropriate queue based on mode */
  if (src->mode == GST_SSP_MODE_VIDEO_ONLY || 
      (src->mode == GST_SSP_MODE_BOTH && (src->has_video_meta || !src->has_audio_meta))) {
    /* Block until we get a video buffer */
    GST_DEBUG_OBJECT (src, "Waiting for video buffer from queue (length=%d)", g_async_queue_length(src->video_queue));
    buffer = GST_BUFFER (g_async_queue_pop (src->video_queue));
    if (buffer) {
      GST_DEBUG_OBJECT (src, "Got video buffer of size %zu", gst_buffer_get_size(buffer));
    }
  } else if (src->mode == GST_SSP_MODE_AUDIO_ONLY || 
             (src->mode == GST_SSP_MODE_BOTH && src->has_audio_meta)) {
    buffer = GST_BUFFER (g_async_queue_pop (src->audio_queue));
    if (buffer) {
      GST_DEBUG_OBJECT (src, "Got audio buffer of size %zu", gst_buffer_get_size(buffer));
    }
  }

  if (buffer == NULL) {
    GST_DEBUG_OBJECT (src, "No buffer received (disconnected?)");
    return GST_FLOW_EOS;
  }

  GST_DEBUG_OBJECT (src, "Returning buffer with PTS %" GST_TIME_FORMAT, 
                    GST_TIME_ARGS(GST_BUFFER_PTS(buffer)));

  *buf = buffer;
  return GST_FLOW_OK;
}

static gboolean
gst_ssp_src_unlock (GstBaseSrc * basesrc)
{
  GstSspSrc *src = GST_SSP_SRC (basesrc);
  
  /* Push EOS buffer to unblock create function */
  GstBuffer *eos_buffer = gst_buffer_new ();
  GST_BUFFER_FLAG_SET (eos_buffer, GST_BUFFER_FLAG_GAP);
  
  g_async_queue_push (src->video_queue, eos_buffer);
  g_async_queue_push (src->audio_queue, gst_buffer_ref (eos_buffer));
  
  return TRUE;
}

static gboolean
gst_ssp_src_unlock_stop (GstBaseSrc * basesrc)
{
  GstSspSrc *src = GST_SSP_SRC (basesrc);
  
  /* Clear any EOS buffers */
  gpointer buffer;
  while ((buffer = g_async_queue_try_pop (src->video_queue)) != NULL) {
    if (GST_BUFFER_FLAG_IS_SET (GST_BUFFER (buffer), GST_BUFFER_FLAG_GAP)) {
      gst_buffer_unref (GST_BUFFER (buffer));
    } else {
      g_async_queue_push_front (src->video_queue, buffer);
      break;
    }
  }
  while ((buffer = g_async_queue_try_pop (src->audio_queue)) != NULL) {
    if (GST_BUFFER_FLAG_IS_SET (GST_BUFFER (buffer), GST_BUFFER_FLAG_GAP)) {
      gst_buffer_unref (GST_BUFFER (buffer));
    } else {
      g_async_queue_push_front (src->audio_queue, buffer);
      break;
    }
  }
  
  return TRUE;
}

static void
on_video_data_cb (SspVideoData data, gpointer user_data)
{
  GstSspSrc *src = GST_SSP_SRC (user_data);
  GstBuffer *buffer;
  GstMemory *memory;
  
  GST_DEBUG_OBJECT (src, "Received video frame: size=%zu, pts=%" G_GUINT64_FORMAT ", type=%u", 
                    data.len, data.pts, data.type);
  
  /* Create GStreamer buffer */
  memory = gst_memory_new_wrapped (GST_MEMORY_FLAG_READONLY, data.data, data.len, 0, data.len, data.data, g_free);
  buffer = gst_buffer_new ();
  gst_buffer_append_memory (buffer, memory);
  
  /* Set timestamps based on wall clock for live stream */
  GstClockTime now = gst_util_get_timestamp();
  
  if (src->first_timestamp == GST_CLOCK_TIME_NONE) {
    src->first_timestamp = now;
    src->timestamp = 0;
  } else {
    /* Calculate running time from first timestamp */
    src->timestamp = now - src->first_timestamp;
  }
  
  GST_BUFFER_PTS (buffer) = src->timestamp;
  GST_BUFFER_DTS (buffer) = src->timestamp;
  GST_BUFFER_DURATION (buffer) = GST_SECOND / 30; /* Assume 30fps for video */
  
  /* Update codec type if detected from stream and different from metadata */
  if (data.codec_type != 0 && src->video_encoder != data.codec_type) {
    GST_INFO_OBJECT (src, "Detected codec change from %d to %d", src->video_encoder, data.codec_type);
    src->video_encoder = data.codec_type;
  }
  
  /* Set caps only once when we first have metadata and caps aren't set yet */
  /* For proper decoding, we should wait for an I-frame (keyframe) before setting caps */
  if ((src->has_video_meta || data.codec_type != 0) && !src->video_caps_set && data.type == 5) {
    GstCaps *caps = NULL;
    guint32 encoder = src->video_encoder;
    
    /* Use detected codec if metadata encoder is unknown */
    if (encoder == VIDEO_ENCODER_UNKNOWN && data.codec_type != 0) {
      encoder = data.codec_type;
    }
    
    if (encoder == VIDEO_ENCODER_H264) {
      caps = gst_caps_new_simple ("video/x-h264",
          "stream-format", G_TYPE_STRING, "byte-stream",
          "alignment", G_TYPE_STRING, "nal",
          NULL);
      
      /* Add dimensions if available */
      if (src->has_video_meta && src->video_width > 0 && src->video_height > 0) {
        gst_caps_set_simple (caps,
            "width", G_TYPE_INT, src->video_width,
            "height", G_TYPE_INT, src->video_height,
            NULL);
      }
    } else if (encoder == VIDEO_ENCODER_H265) {
      caps = gst_caps_new_simple ("video/x-h265",
          "stream-format", G_TYPE_STRING, "byte-stream",
          "alignment", G_TYPE_STRING, "nal",
          NULL);
      
      /* Add dimensions if available */
      if (src->has_video_meta && src->video_width > 0 && src->video_height > 0) {
        gst_caps_set_simple (caps,
            "width", G_TYPE_INT, src->video_width,
            "height", G_TYPE_INT, src->video_height,
            NULL);
      }
    }
    
    if (caps) {
      GST_INFO_OBJECT (src, "Setting video caps with I-frame: %" GST_PTR_FORMAT, caps);
      if (gst_base_src_set_caps (GST_BASE_SRC (src), caps)) {
        src->video_caps_set = TRUE;
      }
      gst_caps_unref (caps);
    }
  }
  
  /* Only push frames to queue if caps are set or it's an I-frame */
  if (!src->video_caps_set && data.type != 5) {
    GST_DEBUG_OBJECT (src, "Skipping P-frame before caps are set (waiting for I-frame)");
    g_free (data.data);
    return;
  }
  
  g_async_queue_push (src->video_queue, buffer);
}

static void
on_audio_data_cb (SspAudioData data, gpointer user_data)
{
  GstSspSrc *src = GST_SSP_SRC (user_data);
  GstBuffer *buffer;
  GstMemory *memory;
  
  /* Create GStreamer buffer */
  memory = gst_memory_new_wrapped (GST_MEMORY_FLAG_READONLY, data.data, data.len, 0, data.len, data.data, g_free);
  buffer = gst_buffer_new ();
  gst_buffer_append_memory (buffer, memory);
  
  /* Set timestamps based on wall clock for live stream */
  GstClockTime now = gst_util_get_timestamp();
  
  if (src->first_timestamp == GST_CLOCK_TIME_NONE) {
    src->first_timestamp = now;
    src->timestamp = 0;
  } else {
    /* Calculate running time from first timestamp */
    src->timestamp = now - src->first_timestamp;
  }
  
  GST_BUFFER_PTS (buffer) = src->timestamp;
  GST_BUFFER_DTS (buffer) = src->timestamp;
  GST_BUFFER_DURATION (buffer) = GST_CLOCK_TIME_NONE;
  
  /* Set caps only once when we first have metadata and caps aren't set yet */
  if (src->has_audio_meta && !src->audio_caps_set) {
    GstCaps *caps = NULL;
    if (src->audio_encoder == AUDIO_ENCODER_AAC) {
      caps = gst_caps_new_simple ("audio/mpeg",
          "mpegversion", G_TYPE_INT, 4,
          "stream-format", G_TYPE_STRING, "raw",
          "rate", G_TYPE_INT, src->audio_sample_rate,
          "channels", G_TYPE_INT, src->audio_channels,
          NULL);
    } else if (src->audio_encoder == AUDIO_ENCODER_PCM) {
      caps = gst_caps_new_simple ("audio/x-raw",
          "format", G_TYPE_STRING, "S16LE",
          "layout", G_TYPE_STRING, "interleaved",
          "rate", G_TYPE_INT, src->audio_sample_rate,
          "channels", G_TYPE_INT, src->audio_channels,
          NULL);
    }
    
    if (caps) {
      GST_INFO_OBJECT (src, "Setting audio caps (once): %" GST_PTR_FORMAT, caps);
      if (gst_base_src_set_caps (GST_BASE_SRC (src), caps)) {
        src->audio_caps_set = TRUE;
      }
      gst_caps_unref (caps);
    }
  }
  
  g_async_queue_push (src->audio_queue, buffer);
}

static void
on_meta_cb (SspVideoMeta video_meta, SspAudioMeta audio_meta, SspMeta meta, gpointer user_data)
{
  GstSspSrc *src = GST_SSP_SRC (user_data);
  
  GST_DEBUG_OBJECT (src, "Received metadata: video %dx%d encoder=%d, audio rate=%d channels=%d encoder=%d",
      video_meta.width, video_meta.height, video_meta.encoder,
      audio_meta.sample_rate, audio_meta.channel, audio_meta.encoder);
  
  /* Store video metadata */
  src->video_width = video_meta.width;
  src->video_height = video_meta.height;
  src->video_encoder = video_meta.encoder;
  src->video_timescale = video_meta.timescale;
  src->video_unit = video_meta.unit;
  src->video_gop = video_meta.gop;
  src->has_video_meta = TRUE;
  
  /* Store audio metadata */
  src->audio_sample_rate = audio_meta.sample_rate;
  src->audio_channels = audio_meta.channel;
  src->audio_sample_size = audio_meta.sample_size;
  src->audio_encoder = audio_meta.encoder;
  src->audio_timescale = audio_meta.timescale;
  src->audio_unit = audio_meta.unit;
  src->audio_bitrate = audio_meta.bitrate;
  src->has_audio_meta = TRUE;
  
  /* Store general metadata */
  src->pts_is_wall_clock = meta.pts_is_wall_clock;
  src->tc_drop_frame = meta.tc_drop_frame;
  src->timecode = meta.timecode;
}

static void
on_connected_cb (gpointer user_data)
{
  GstSspSrc *src = GST_SSP_SRC (user_data);
  
  GST_INFO_OBJECT (src, "SSP client connected");
  
  g_mutex_lock (&src->lock);
  src->connected = TRUE;
  g_cond_signal (&src->cond);
  g_mutex_unlock (&src->lock);
}

static void
on_disconnected_cb (gpointer user_data)
{
  GstSspSrc *src = GST_SSP_SRC (user_data);
  
  GST_WARNING_OBJECT (src, "SSP client disconnected");
  
  g_mutex_lock (&src->lock);
  src->connected = FALSE;
  g_mutex_unlock (&src->lock);
}

static void
gst_ssp_src_get_times (GstBaseSrc * basesrc, GstBuffer * buffer,
    GstClockTime * start, GstClockTime * end)
{
  /* For live sources, we use the buffer timestamp as start time */
  if (GST_BUFFER_TIMESTAMP_IS_VALID (buffer)) {
    *start = GST_BUFFER_TIMESTAMP (buffer);
    if (GST_BUFFER_DURATION_IS_VALID (buffer)) {
      *end = *start + GST_BUFFER_DURATION (buffer);
    } else {
      *end = GST_CLOCK_TIME_NONE;
    }
  } else {
    *start = GST_CLOCK_TIME_NONE;
    *end = GST_CLOCK_TIME_NONE;
  }
}

static void
on_exception_cb (gint code, const gchar* description, gpointer user_data)
{
  GstSspSrc *src = GST_SSP_SRC (user_data);
  
  GST_ERROR_OBJECT (src, "SSP client exception: code=%d, description=%s", code, description);
}
