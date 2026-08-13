# @summary Manages the Mattermost service
#
# @api private
class mattermost::service {
  assert_private()

  if $mattermost::service_manage {
    if $mattermost::install_method == 'archive' {
      # Tarball installs ship no systemd unit; the managed one loads
      # the environment file directly.
      file { "/etc/systemd/system/${mattermost::service_name}.service":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => epp('mattermost/mattermost.service.epp', {
          'install_dir' => $mattermost::install_dir,
          'user'        => $mattermost::user,
          'group'       => $mattermost::group,
          'env_file'    => $mattermost::env_file,
        }),
        notify  => Service[$mattermost::service_name],
      }
    } else {
      # The package ships its own unit; a drop-in adds the environment
      # file the module renders.
      file { "/etc/systemd/system/${mattermost::service_name}.service.d":
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      file { "/etc/systemd/system/${mattermost::service_name}.service.d/puppet.conf":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "# This file is managed by Puppet.\n[Service]\nEnvironmentFile=-${mattermost::env_file}\n",
        notify  => Service[$mattermost::service_name],
      }
    }

    service { $mattermost::service_name:
      ensure => $mattermost::service_ensure,
      enable => $mattermost::service_enable,
    }
  }
}
