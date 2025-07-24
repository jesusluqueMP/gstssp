#ifndef __GST_SSP_SRC_H__
#define __GST_SSP_SRC_H__

#include <gst/gst.h>
#include <gst/base/gstpushsrc.h>

G_BEGIN_DECLS

#define GST_TYPE_SSP_SRC \
  (gst_ssp_src_get_type())
#define GST_SSP_SRC(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_SSP_SRC,GstSspSrc))
#define GST_SSP_SRC_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass),GST_TYPE_SSP_SRC,GstSspSrcClass))
#define GST_IS_SSP_SRC(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_SSP_SRC))
#define GST_IS_SSP_SRC_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass),GST_TYPE_SSP_SRC))

typedef struct _GstSspSrc      GstSspSrc;
typedef struct _GstSspSrcClass GstSspSrcClass;

typedef enum {
  GST_SSP_STREAM_DEFAULT = 0,
  GST_SSP_STREAM_MAIN = 1,
  GST_SSP_STREAM_SEC = 2
} GstSspStreamStyle;

typedef enum {
  GST_SSP_MODE_VIDEO_ONLY = 0,
  GST_SSP_MODE_AUDIO_ONLY = 1,
  GST_SSP_MODE_BOTH = 2
} GstSspMode;

struct _GstSspSrc
{
  GstPushSrc element;

  /* properties */
  gchar *ip;
  guint16 port;
  GstSspStreamStyle stream_style;
  GstSspMode mode;
  guint buffer_size;
  guint32 capability;
  gboolean is_hlg;

  /* private */
  gpointer ssp_thread;        /* SspThread* wrapped as gpointer for C compatibility */
  GstPad *video_pad;
  GstPad *audio_pad;
  GAsyncQueue *video_queue;
  GAsyncQueue *audio_queue;
  
  gboolean started;
  gboolean connected;
  gboolean has_video_meta;
  gboolean has_audio_meta;
  gboolean video_caps_set;
  gboolean audio_caps_set;
  
  /* current stream info */
  guint32 video_width;
  guint32 video_height;
  guint32 video_encoder;
  guint32 video_timescale;
  guint32 video_unit;
  guint32 video_gop;
  
  guint32 audio_sample_rate;
  guint32 audio_channels;
  guint32 audio_sample_size;
  guint32 audio_encoder;
  guint32 audio_timescale;
  guint32 audio_unit;
  guint32 audio_bitrate;
  
  gboolean pts_is_wall_clock;
  gboolean tc_drop_frame;
  guint32 timecode;
  
  /* timestamp tracking */
  GstClockTime timestamp;
  GstClockTime first_timestamp;
  
  GMutex lock;
  GCond cond;
};

struct _GstSspSrcClass 
{
  GstPushSrcClass parent_class;
};

GType gst_ssp_src_get_type (void);

G_END_DECLS

#endif /* __GST_SSP_SRC_H__ */
