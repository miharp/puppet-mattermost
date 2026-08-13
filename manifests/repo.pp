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
      # The upstream key is ASCII-armored, so the keyring must be named
      # .asc — apt treats a .gpg extension as binary format and ignores
      # the key.
      key      => {
        name   => 'mattermost-archive-keyring.asc',
        source => 'https://deb.packages.mattermost.com/pubkey.gpg',
      },
    }
  }
}
