# define: nginx::resource::location
#
# This definition creates a new location entry within a virtual host
#
# Parameters:
#   [*ensure*]      - Enables or disables the specified location (present|absent)
#   [*vhost*]       - Defines the default vHost for this location entry to include with
#   [*location*]    - Specifies the URI associated with this location entry
#   [*www_root*]    - Specifies the location on disk for files to be read from. Cannot be set in conjunction with $proxy
#   [*index_files*] - Default index files for NGINX to read when traversing a directory
#   [*proxy*]       - Proxy server(s) for a location to connect to. Accepts a single value, can be used in conjunction
#                     with nginx::resource::upstream
#   [*ssl*]         - Indicates whether to setup SSL bindings for this location.
#   [*option*]      - Reserved for future use
#
# Actions:
#
# Requires:
#
# Sample Usage:
#  nginx::resource::location { 'test2.local-bob':
#    ensure   => present,
#    www_root => '/var/www/bob',
#    location => '/bob',
#    vhost    => 'test2.local',
#  }
define nginx::resource::location(
  $ensure      = present,
  $vhost       = undef,
  $type        = 'directory',
  $upstream    = undef,
  $www_root    = undef,
  $index_files = ['index.html', 'index.htm', 'index.php']
) {

  if ($vhost == undef) {
    fail('Cannot create a location reference without attaching to a virtual host')
  }

  case $type {

    proxy: { 
      if ($upstream == undef){
        fail('Cannot create a proxy location if upstream is not defined')
      }
      $ct = template('templates/vhost/vhost_location_proxy.erb') 
    }

    directory: { 
      if ($www_root == undef){
        fail('Cannont create a directory location if www_root is not defined')
      }
      $ct = template('templates/vhost/vhost_location_directory.erb') 
    }

    uwsgi: { 
      if ($upstream == undef){
        fail('Cannot create a uwsgi location if upstream is not defined')
      }
      $ct = template('templates/vhost/vhost_location_uwsgi.erb') 
    }

  }

  ## Create stubs for vHost File Fragment Pattern
  concat::fragment { "${vhost}_${location}" :
    target => "${nginx::config::nx_sites_available_dir}/${vhost}.conf",
    content => $ct,
    order => 50,
    notify => Class['nginx::service'],
  }

  ## Only create SSL Specific locations if $ssl is true.
  # if ($ssl == 'true') {
  #   file {"${nginx::config::nx_temp_dir}/nginx.d/${vhost}-800-${name}-ssl":
  #     ensure  => $ensure_real,
  #     content => $content_real,
  #   }
  # }
}
