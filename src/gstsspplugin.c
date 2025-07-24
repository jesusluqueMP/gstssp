#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <gst/gst.h>
#include "gstsspsrc.h"

static gboolean
plugin_init (GstPlugin * plugin)
{
  if (!gst_element_register (plugin, "sspsrc", GST_RANK_NONE,
          GST_TYPE_SSP_SRC))
    return FALSE;

  return TRUE;
}

GST_PLUGIN_DEFINE (GST_VERSION_MAJOR,
    GST_VERSION_MINOR,
    ssp,
    "Simple Stream Protocol (SSP) source plugin for Z CAM cameras",
    plugin_init, PACKAGE_VERSION, GST_LICENSE, GST_PACKAGE_NAME,
    GST_PACKAGE_ORIGIN)
