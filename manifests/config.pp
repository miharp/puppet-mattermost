# @summary Manages the Mattermost config.json
#
# @api private
class mattermost::config {
  assert_private()

  $data_source = sprintf(
    'postgres://%s:%s@%s:%d/%s?sslmode=%s&connect_timeout=10',
    $mattermost::db_user,
    $mattermost::db_password.unwrap,
    $mattermost::db_host,
    $mattermost::db_port,
    $mattermost::db_name,
    $mattermost::db_sslmode,
  )

  $support_settings = $mattermost::support_email ? {
    undef   => {},
    default => { 'SupportSettings' => { 'SupportEmail' => $mattermost::support_email } },
  }

  $settings = {
    'ServiceSettings' => {
      'SiteURL' => $mattermost::site_url,
    },
    'SqlSettings'     => {
      'DriverName' => 'postgres',
      'DataSource' => $data_source,
    },
  } + $support_settings

  # Mattermost fills in defaults for any key missing from config.json,
  # so only the settings this module knows about are rendered.
  $config = deep_merge($settings, $mattermost::override_options)

  file { "${mattermost::install_dir}/config/config.json":
    ensure    => file,
    owner     => 'mattermost',
    group     => 'mattermost',
    mode      => '0600',
    content   => Sensitive(stdlib::to_json_pretty($config)),
    show_diff => false,
  }
}
