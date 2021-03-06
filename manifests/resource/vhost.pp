# define: nginx::resource::location
#
# This definition creates a new location entry within a virtual host
#
# Parameters:
#   [*ensure*]           - Enables or disables the specified location (present|absent)
#   [*listen_ip*]        - Default IP Address for NGINX to listen with this vHost on. Defaults to all interfaces (*)
#   [*listen_port*]      - Default IP Port for NGINX to listen with this vHost on. Defaults to TCP 80
#   [*ipv6_enable*]      - BOOL value to enable/disable IPv6 support (false|true). Module will check to see if IPv6
#                          support exists on your system before enabling.
#   [*ipv6_listen_ip*]   - Default IPv6 Address for NGINX to listen with this vHost on. Defaults to all interfaces (::)
#   [*ipv6_listen_port*] - Default IPv6 Port for NGINX to listen with this vHost on. Defaults to TCP 80
#   [*index_files*]      -  Default index files for NGINX to read when traversing a directory
#   [*proxy*]            - Proxy server(s) for a location to connect to. Accepts a single value, can be used in conjunction
#                          with nginx::resource::upstream
#   [*ssl*]              - Indicates whether to setup SSL bindings for this location.
#   [*ssl_cert*]         - Pre-generated SSL Certificate file to reference for SSL Support. This is not generated by this module.
#   [*ssl_key*]          - Pre-generated SSL Key file to reference for SSL Support. This is not generated by this module.
#   [*www_root*]         - Specifies the location on disk for files to be read from. Cannot be set in conjunction with $proxy
#
# Actions:
#
# Requires:
#
# Sample Usage:
#  nginx::resource::vhost { 'test2.local':
#    ensure   => present,
#    www_root => '/var/www/nginx-default',
#    ssl      => 'true',
#    ssl_cert => '/tmp/server.crt',
#    ssl_key  => '/tmp/server.pem',
#  }
define nginx::resource::vhost(
  $ensure           = 'absent',
  $listen_ip        = '*',
  $listen_port      = '80',

  $ipv6_enable      = false,
  $ipv6_listen_ip   = '::',
  $ipv6_listen_port = '80',

  $ssl              = false,
  $ssl_cert         = undef,
  $ssl_key          = undef,

  $proxy            = undef,

  $index_files      = ['index.html', 'index.htm', 'index.php'],
  $www_root         = "/srv/www/${name}"
) {

  # Ensure root directory exists and permissions are correct.
  file { $www_root:
    ensure => directory,
    group => 'www-data',
    owner => 'www-data',
    mode => 0644
  }

  # Add IPv6 Logic Check - Nginx service will not start if ipv6 is enabled
  # and support does not exist for it in the kernel.
  if ($ipv6_enable == 'true') and ($ipaddress6)  {
    warning('nginx: IPv6 support is not enabled or configured properly')
  }

  # Check to see if SSL Certificates are properly defined.
  if ($ssl == 'true') {
    if ($ssl_cert == undef) or ($ssl_key == undef) {
      fail('nginx: SSL certificate/key (ssl_cert/ssl_cert) and/or SSL Private must be defined and exist on the target system(s)')
    }
  }

  # Create vhost file using concat pattern.
  $vhost = "${nginx::config::nx_sites_available_dir}/${name}.conf"

  concat { $vhost : 
    owner => 'www-data',
    group => 'www-data',
    mode => 0644,
    notify   => Class['nginx::service'],
  }

  # Add header to vhost file.
  concat::fragment { "vhost_header" :
    target => $vhost,
    content => $ssl ? { # If SSL is enabled use SSL header and redirect all unsecured traffic to SSL.
      'true' => template('nginx/vhost/vhost_ssl_header.erb'),
      default => template('nginx/vhost/vhost_header.erb'),    
    },
    ensure  => 'present',
    order => 01
  }

  concat::fragment { "vhost_location_ignore" :
    target => $vhost,
    content => template('nginx/vhost/vhost_location_ignore.erb'),
    ensure => 'present',
    order => 998
  }

  # Add footer to vhost file.
  concat::fragment { "vhost_footer" : 
    target => $vhost,
    content => template('nginx/vhost/vhost_footer.erb'),
    ensure  => 'present',
    order => 999
  }


  # If enabled create symlink to sites-enabled. If not, ensure symlink does not exist.
  file { "${nginx::config::nx_sites_enabled_dir}/${name}.conf":
    ensure => $ensure ? {
      'enabled' => link,
      default  => absent,
    },
    target => $vhost,
  }

}
