project('gst-ssp', 'c', 'cpp',
  version : '1.0.0',
  license : 'LGPL',
  default_options : [
    'warning_level=1',
    'buildtype=debugoptimized',
    'cpp_std=c++11'
  ]
)

gst_version = meson.project_version()

api_version = '1.0'

gst_req = '>= 1.16.0'

glib_dep = dependency('glib-2.0', version : '>= 2.44')
gst_dep = dependency('gstreamer-1.0', version : gst_req)
gstbase_dep = dependency('gstreamer-base-1.0', version : gst_req)
gstvideo_dep = dependency('gstreamer-video-1.0', version : gst_req)
gstaudio_dep = dependency('gstreamer-audio-1.0', version : gst_req)

# Get C compiler for library detection
cc = meson.get_compiler('c')

plugin_c_args = ['-DHAVE_CONFIG_H']

cdata = configuration_data()
cdata.set_quoted('PACKAGE_VERSION', gst_version)
cdata.set_quoted('PACKAGE', 'gst-ssp')
cdata.set_quoted('GST_LICENSE', 'LGPL')
cdata.set_quoted('GST_API_VERSION', api_version)
cdata.set_quoted('GST_PACKAGE_NAME', 'GStreamer SSP Plug-ins')
cdata.set_quoted('GST_PACKAGE_ORIGIN', 'https://github.com/your-repo/gst-ssp')

configure_file(output : 'config.h', configuration : cdata)

# Include libssp headers
libssp_inc = include_directories('libssp/include')

# Detect platform and select appropriate libssp library
host_system = host_machine.system()
if host_system == 'darwin'
  if host_machine.cpu() == 'aarch64'
    libssp_lib_dir = 'libssp/lib/mac_arm64'
  else
    libssp_lib_dir = 'libssp/lib/mac'
  endif
  libssp_lib_name = 'ssp'
  libssp_lib_suffix = '.dylib'
elif host_system == 'linux'
  libssp_lib_dir = 'libssp/lib/linux_x64'
  libssp_lib_name = 'ssp'
  libssp_lib_suffix = '.so'
elif host_system == 'windows'
  libssp_lib_dir = 'libssp/lib/win_x64_vs2017'
  libssp_lib_name = 'ssp'
  libssp_lib_suffix = '.dll'
else
  error('Unsupported platform: ' + host_system)
endif

libssp_dep = declare_dependency(
  include_directories : libssp_inc,
  dependencies : [
    cc.find_library(libssp_lib_name, dirs : join_paths(meson.current_source_dir(), libssp_lib_dir))
  ]
)

subdir('src')
