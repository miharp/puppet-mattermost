# @summary Installs and configures a Mattermost server
#
# Installs Mattermost from the official apt repository on Debian-family
# systems, or from the official release tarball on RedHat-family systems
# (Mattermost publishes no yum/dnf repository), manages its settings
# through `MM_*` environment variables, and manages the `mattermost`
# systemd service. The PostgreSQL database can be managed on the same
# host with `manage_database => true`, or provided externally via the
# `db_*` parameters.
#
# Settings are managed as environment variables (which override
# config.json) instead of managing config.json itself, because
# Mattermost rewrites that file at startup. Settings the module does
# not manage remain changeable through the System Console and persist.
#
# @example Minimal usage on Ubuntu
#   class { 'mattermost':
#     site_url    => 'https://mattermost.example.com',
#     db_password => Sensitive('supersecret'),
#   }
#
# @example Minimal usage on RHEL (version is required for tarball installs)
#   class { 'mattermost':
#     site_url    => 'https://mattermost.example.com',
#     db_password => Sensitive('supersecret'),
#     version     => '11.9.1',
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
# @param manage_database
#   Whether to manage a PostgreSQL server on this host (via
#   puppetlabs/postgresql) and create the Mattermost database and user
#   on it, following the upstream database preparation guide. Only
#   makes sense when db_host is this host. To customize the PostgreSQL
#   server itself, declare `class { 'postgresql::server': ... }` before
#   this class instead of relying on the defaults included here.
# @param support_email
#   If set, written to SupportSettings.SupportEmail.
# @param override_options
#   A hash of config.json-style sections deep-merged over the settings
#   this module manages, rendered as MM_* environment variables. Use it
#   for any Mattermost setting without a dedicated parameter, e.g.
#   { 'TeamSettings' => { 'SiteName' => 'ACME Chat' } }.
# @param env_file
#   Path of the environment file the module renders and hooks into the
#   systemd service.
# @param install_method
#   How to install Mattermost. 'package' uses the official apt
#   repository (Debian family); 'archive' downloads and extracts the
#   official release tarball (default on the RedHat family, which has
#   no upstream package repository).
# @param version
#   The Mattermost version to install, e.g. '11.9.1'. Required when
#   install_method is 'archive'; ignored otherwise (use package_ensure
#   to pin a package version).
# @param archive_source
#   URL of the release tarball to install. Defaults to the official
#   releases.mattermost.com URL for `version`.
# @param manage_repo
#   Whether to manage the deb.packages.mattermost.com apt repository.
#   Only applies to the Debian family.
# @param package_name
#   Name of the package to install.
# @param package_ensure
#   Ensure value of the package, e.g. 'installed', 'latest' or a version.
# @param install_dir
#   Directory Mattermost is installed into. With install_method
#   'archive' the tarball's top-level directory is named 'mattermost',
#   so this must end in '/mattermost'.
# @param manage_user
#   Whether to manage the Mattermost system user and group. Defaults to
#   true on the RedHat family (the tarball creates no user; the deb
#   package does).
# @param user
#   System user Mattermost runs as and that owns config and data files.
# @param group
#   Group of the Mattermost user.
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
  Boolean $manage_database = false,
  Optional[String[1]] $support_email = undef,
  Hash[String[1], Hash[String[1], Data]] $override_options = {},
  Stdlib::Absolutepath $env_file = '/etc/default/mattermost',
  Enum['package', 'archive'] $install_method = 'package',
  Optional[String[1]] $version = undef,
  Optional[Stdlib::HTTPUrl] $archive_source = undef,
  Boolean $manage_repo = true,
  String[1] $package_name = 'mattermost',
  String[1] $package_ensure = 'installed',
  Stdlib::Absolutepath $install_dir = '/opt/mattermost',
  Boolean $manage_user = false,
  String[1] $user = 'mattermost',
  String[1] $group = 'mattermost',
  Boolean $service_manage = true,
  String[1] $service_name = 'mattermost',
  Stdlib::Ensure::Service $service_ensure = 'running',
  Boolean $service_enable = true,
) {
  contain mattermost::repo
  contain mattermost::install
  contain mattermost::database
  contain mattermost::config
  contain mattermost::service

  Class['mattermost::repo']
  -> Class['mattermost::install']
  -> Class['mattermost::config']
  ~> Class['mattermost::service']

  Class['mattermost::database'] -> Class['mattermost::service']
}
