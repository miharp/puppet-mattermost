# @summary Manages the official Mattermost apt repository
#
# @api private
class mattermost::repo {
  assert_private()

  if $mattermost::manage_repo {
    unless $facts['os']['family'] == 'Debian' {
      fail("mattermost: Mattermost publishes no package repository for the ${facts['os']['family']} family; use install_method 'archive'")
    }

    include apt

    apt::source { 'mattermost':
      location => 'https://deb.packages.mattermost.com',
      release  => $facts['os']['distro']['codename'],
      repos    => 'main',
      key      => {
        name   => 'mattermost-archive-keyring.gpg',
        source => 'https://deb.packages.mattermost.com/pubkey.gpg',
      },
    }
  }
}
