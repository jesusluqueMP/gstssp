configinc = include_directories('..')
plugins_install_dir = get_option('libdir') / 'gstreamer-1.0'

gstssp_sources = [
  'gstsspsrc.cpp',
  'gstsspplugin.c',
  'sspthread.cpp'
]

gstssp = library('gstssp',
  gstssp_sources,
  c_args : plugin_c_args,
  cpp_args : plugin_c_args,
  include_directories : [configinc],
  dependencies : [glib_dep, gst_dep, gstbase_dep, gstvideo_dep, gstaudio_dep, libssp_dep],
  install : true,
  install_dir : plugins_install_dir,
)
