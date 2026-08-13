# @summary Manages the Mattermost service
#
# @api private
class mattermost::service {
  assert_private()

  if $mattermost::service_manage {
    service { $mattermost::service_name:
      ensure => $mattermost::service_ensure,
      enable => $mattermost::service_enable,
    }
  }
}
