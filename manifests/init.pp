# @summary Installs and configures a Mattermost server on Ubuntu
#
# Installs Mattermost from the official apt repository, manages
# `config.json`, and manages the `mattermost` systemd service. The
# PostgreSQL database itself is expected to exist already (see the
# README for an example using puppetlabs/postgresql).
#
# @example Minimal usage
#   class { 'mattermost':
#     site_url    => 'https://mattermost.example.com',
#     db_password => Sensitive('supersecret'),
#   }
#
# @param site_url
#   The URL users reach the server at, e.g. 'https://mattermost.example.com'.
#   Written to ServiceSettings.SiteURL.
# @param db_password
#   Password of the PostgreSQL user. Used to build SqlSettings.DataSource.
# @param db_user
#   PostgreSQL user Mattermost connects as.
# @param db_host
#   PostgreSQL host to connect to.
# @param db_port
#   PostgreSQL port to connect to.
# @param db_name
#   Name of the Mattermost database.
# @param db_sslmode
#   The sslmode used in the PostgreSQL connection string. Use 'disable'
#   for a local database, 'require' or stricter for remote databases.
# @param support_email
#   If set, written to SupportSettings.SupportEmail.
# @param override_options
#   A hash deep-merged over the settings this module renders into
#   config.json. Use it for any Mattermost setting without a dedicated
#   parameter, e.g. { 'TeamSettings' => { 'SiteName' => 'ACME Chat' } }.
# @param manage_repo
#   Whether to manage the deb.packages.mattermost.com apt repository.
# @param package_name
#   Name of the package to install.
# @param package_ensure
#   Ensure value of the package, e.g. 'installed', 'latest' or a version.
# @param install_dir
#   Directory the package installs Mattermost into.
# @param service_manage
#   Whether to manage the Mattermost service at all.
# @param service_name
#   Name of the service to manage.
# @param service_ensure
#   Desired run state of the service.
# @param service_enable
#   Whether the service starts on boot.
class mattermost (
  String[1] $site_url,
  Sensitive[String[1]] $db_password,
  String[1] $db_user = 'mmuser',
  Stdlib::Host $db_host = 'localhost',
  Stdlib::Port $db_port = 5432,
  String[1] $db_name = 'mattermost',
  Enum['disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full'] $db_sslmode = 'disable',
  Optional[String[1]] $support_email = undef,
  Hash $override_options = {},
  Boolean $manage_repo = true,
  String[1] $package_name = 'mattermost',
  String[1] $package_ensure = 'installed',
  Stdlib::Absolutepath $install_dir = '/opt/mattermost',
  Boolean $service_manage = true,
  String[1] $service_name = 'mattermost',
  Stdlib::Ensure::Service $service_ensure = 'running',
  Boolean $service_enable = true,
) {
  contain mattermost::repo
  contain mattermost::install
  contain mattermost::config
  contain mattermost::service

  Class['mattermost::repo']
  -> Class['mattermost::install']
  -> Class['mattermost::config']
  ~> Class['mattermost::service']
}
