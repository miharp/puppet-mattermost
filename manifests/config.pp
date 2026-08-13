# @summary Manages Mattermost settings via an environment file
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

  $config = deep_merge($settings, $mattermost::override_options)

  # Mattermost is configured through MM_* environment variables rather
  # than a managed config.json: the server rewrites config.json at
  # startup (persisting defaults and System Console changes into it),
  # so a Puppet-managed config.json would be reverted on every run and
  # restart the service each time. Environment variables take
  # precedence over config.json, and settings without one keep working
  # through the System Console.
  $env_lines = sort($config.map |$section, $keys| {
    $keys.map |$key, $value| {
      $value_string = $value ? {
        String  => $value,
        default => stdlib::to_json($value),
      }
      sprintf('MM_%s_%s=%s', $section.upcase, $key.upcase, $value_string)
    }
  }.flatten)

  # systemd reads the EnvironmentFile as root before dropping
  # privileges, so the database password is never readable by the
  # mattermost user.
  file { $mattermost::env_file:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0600',
    content   => Sensitive("${env_lines.join("\n")}\n"),
    show_diff => false,
  }
}
