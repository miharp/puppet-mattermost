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
      }

      # The tarball's top-level directory is 'mattermost', so it is
      # extracted into the parent of install_dir.
      $extract_path = regsubst($mattermost::install_dir, '/[^/]+$', '')

      archive { "mattermost-${version}.tar.gz":
        path         => "/var/tmp/mattermost-${version}.tar.gz",
        source       => $source,
        extract      => true,
        extract_path => $extract_path,
        creates      => "${mattermost::install_dir}/bin/mattermost",
        cleanup      => true,
      }

      # The tarball extracts with the packager's uid/gid, and the data
      # directory is not part of the archive.
      exec { 'mattermost-install-ownership':
        command     => "chown -R ${mattermost::user}:${mattermost::group} ${mattermost::install_dir}",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        subscribe   => Archive["mattermost-${version}.tar.gz"],
      }

      file { "${mattermost::install_dir}/data":
        ensure  => directory,
        owner   => $mattermost::user,
        group   => $mattermost::group,
        mode    => '0750',
        require => Archive["mattermost-${version}.tar.gz"],
      }

      if $mattermost::manage_user {
        User[$mattermost::user] -> Exec['mattermost-install-ownership']
        User[$mattermost::user] -> File["${mattermost::install_dir}/data"]
      }
    }
    default: {
      fail("mattermost: unsupported install_method '${mattermost::install_method}'")
    }
  }
}
