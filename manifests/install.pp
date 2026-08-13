# @summary Installs the Mattermost server package
#
# @api private
class mattermost::install {
  assert_private()

  package { $mattermost::package_name:
    ensure => $mattermost::package_ensure,
  }

  if $mattermost::manage_repo {
    Class['apt::update'] -> Package[$mattermost::package_name]
  }
}
