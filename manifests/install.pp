# @summary Installs the Mattermost server
#
# @api private
class mattermost::install {
  assert_private()

  case $mattermost::install_method {
    'package': {
      package { $mattermost::package_name:
        ensure => $mattermost::package_ensure,
      }

      if $mattermost::manage_repo {
        Class['apt::update'] -> Package[$mattermost::package_name]
      }

      # The package creates the mattermost user.
      $owner_require = Package[$mattermost::package_name]
    }
    'archive': {
      $version = $mattermost::version
      if $version =~ Undef {
        fail("mattermost: 'version' is required when install_method is 'archive'")
      }

      case $facts['os']['architecture'] {
        'x86_64', 'amd64': { $arch = 'amd64' }
        'aarch64', 'arm64': { $arch = 'arm64' }
        default: {
          fail("mattermost: no Mattermost release tarball exists for architecture '${facts['os']['architecture']}'")
        }
      }

      $source = pick(
        $mattermost::archive_source,
        "https://releases.mattermost.com/${version}/mattermost-${version}-linux-${arch}.tar.gz",
      )

      if $mattermost::manage_user {
        group { $mattermost::group:
          ensure => present,
          system => true,
        }

        user { $mattermost::user:
          ensure => present,
          system => true,
          gid    => $mattermost::group,
          home   => $mattermost::install_dir,
          shell  => '/usr/sbin/nologin',
        }

        $owner_require = User[$mattermost::user]
      } else {
        $owner_require = undef
      }

      # Each version is extracted into its own directory and install_dir
      # is a symlink to the current one, so raising `version` installs
      # the new release alongside the old and flips the link (the
      # previous directory is kept for rollback). config.json and
      # uploaded files live outside the versioned directory (see
      # config_file and data_dir) so they survive the switch.
      $versioned_dir = "${mattermost::install_dir}-${version}"

      file { $versioned_dir:
        ensure  => directory,
        owner   => $mattermost::user,
        group   => $mattermost::group,
        mode    => '0755',
        require => $owner_require,
      }

      # The tarball's top-level directory is 'mattermost', stripped so
      # the contents land directly in the versioned directory.
      archive { "mattermost-${version}.tar.gz":
        path            => "/var/tmp/mattermost-${version}.tar.gz",
        source          => $source,
        extract         => true,
        extract_path    => $versioned_dir,
        extract_command => 'tar --strip-components=1 -xzf %s',
        creates         => "${versioned_dir}/bin/mattermost",
        cleanup         => true,
        require         => File[$versioned_dir],
      }

      # The tarball extracts with the packager's uid/gid, and Mattermost
      # writes into its install directory (logs, plugins, client).
      exec { 'mattermost-install-ownership':
        command     => "chown -R ${mattermost::user}:${mattermost::group} ${versioned_dir}",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        subscribe   => Archive["mattermost-${version}.tar.gz"],
        require     => $owner_require,
      }

      file { $mattermost::install_dir:
        ensure  => link,
        target  => $versioned_dir,
        require => Exec['mattermost-install-ownership'],
      }
    }
    default: {
      fail("mattermost: unsupported install_method '${mattermost::install_method}'")
    }
  }

  if $mattermost::effective_data_dir =~ NotUndef {
    file { $mattermost::effective_data_dir:
      ensure  => directory,
      owner   => $mattermost::user,
      group   => $mattermost::group,
      mode    => '0750',
      require => $owner_require,
    }
  }

  if $mattermost::effective_config_file =~ NotUndef {
    # Mattermost creates config.json itself when MM_CONFIG points at a
    # missing file, but not the directory, and it rewrites the file at
    # startup, so the directory must be writable by the service user.
    file { dirname($mattermost::effective_config_file):
      ensure  => directory,
      owner   => $mattermost::user,
      group   => $mattermost::group,
      mode    => '0750',
      require => $owner_require,
    }
  }
}
