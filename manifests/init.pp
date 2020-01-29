# Class: puppet-sinopia
#
# This module manages sinopia npm-cache-server installations.
#
# Parameters:
#
# conf_admin_pw_hash
# generate the password hash for your plain text password (e.g. newpass) with:
# $ node
# > crypto.createHash('sha1').update('newpass').digest('hex')
#
# conf_listen_to_address
# the ip4 address your proxy is supposed to listen to,
# default 0.0.0.0 (=all addresses)
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class sinopia (
  $install_root              = '/opt',
  $install_dir               = 'sinopia',
  $version                   = latest,    # latest
  $deamon_user               = 'sinopia',
  $conf_listen_to_address    = '0.0.0.0',
  $conf_port                 = '4783',
  $conf_admin_pw_hash,
  $conf_user_pw_combinations = undef,
  $http_proxy                = '',
  $https_proxy               = '',
  $conf_template             = 'sinopia/config.yaml.erb',
  $service_template          = 'sinopia/service.erb',
  $conf_max_body_size        = '1mb',
  $conf_max_age_in_sec       = '86400',
  $install_as_service        = true
) {
  require nodejs
  $install_path = "${install_root}/${install_dir}"

  group { $deamon_user:
    ensure => present,
  }

  user { $deamon_user:
    ensure     => present,
    gid        => $deamon_user,
    managehome => true,
    require    => Group[$deamon_user]
  }

  file { $install_root:
    ensure => directory,
  }

  file { $install_path:
    ensure  => directory,
    owner   => $deamon_user,
    group   => $deamon_user,
    require => [User[$deamon_user], Group[$deamon_user]]
  }

  ### ensures, that always the latest versions of npm modules are installed ###
  $modules_path="${install_path}/node_modules"
  file { $modules_path:
    ensure => absent,
  }

  $service_notify = $install_as_service ? {
    default => undef,
    true => Service['sinopia']
  }
  nodejs::npm { 'sinopia':
    ensure  => $version,
    target  => $install_path,
    require => [File[$install_path,$modules_path],User[$deamon_user]],
    notify  => $service_notify,
    user    => $deamon_user,
    home_dir => $install_path
  }

  ###
  # config.yaml requires $admin_pw_hash, $port, $listen_to_address
  ###
  file { "${install_path}/config.yaml":
    ensure  => present,
    owner   => $deamon_user,
    group   => $deamon_user,
    content => template($conf_template),
    require => File[$install_path],
    notify  => $service_notify,
  }

  if $install_as_service {
    file {'/etc/systemd/system/sinopia.service':
      ensure  => present,
      content => "[Unit]
Description=Sinopia NPM Proxy/Cache Server
After=syslog.target network.target

[Service]
Type=simple
User=${deamon_user}
ExecStart=${install_path}/node_modules/sinopia/bin/sinopia
Restart=always
RestartSec=30
WorkingDirectory=${install_path}

[Install]
WantedBy=multi-user.target
"
    }

    service { 'sinopia':
      ensure    => running,
      provider  => 'systemd',
      enable    => true,
      hasstatus => true,
      restart   => true,
      require   => File['/etc/systemd/system/sinopia.service',"${install_path}/config.yaml"]
    }
  }
}
