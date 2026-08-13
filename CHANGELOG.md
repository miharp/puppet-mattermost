# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial module: apt repository, package, config.json, and service
  management for Mattermost on Ubuntu 20.04/22.04/24.04.
- RHEL-family support (RHEL, Rocky, AlmaLinux, Oracle Linux 8/9): since
  Mattermost publishes no yum/dnf repository, a new `archive` install
  method (default on the RedHat family via hiera) downloads the official
  release tarball with puppet/archive, manages the `mattermost` system
  user/group, and manages the systemd unit. New parameters:
  `install_method`, `version`, `archive_source`, `manage_user`, `user`,
  `group`.
- Optional local database management: `manage_database => true` installs
  a PostgreSQL server via puppetlabs/postgresql and creates the
  Mattermost database and user per the upstream database preparation
  guide (UTF8/template0, Mattermost user as owner for the PostgreSQL
  15+ public-schema requirement).
- Beaker acceptance tests (voxpupuli-acceptance, OpenVox collection)
  covering an end-to-end install with a local database, idempotency,
  and a live API ping.
- GitHub Actions CI via the voxpupuli/gha-puppet reusable workflow:
  static checks, rubocop, unit specs, and per-OS beaker jobs against
  OpenVox 8.

- The archive install method selects the amd64 or arm64 release
  tarball based on the host architecture.
- Settings are managed as MM_* environment variables in an environment
  file (`env_file` parameter) loaded by the systemd unit, instead of a
  managed config.json: Mattermost rewrites config.json at startup, so
  managing it directly reverted the file and restarted the service on
  every agent run (caught by the beaker idempotency test). Environment
  variables take precedence, and unmanaged settings now persist when
  changed in the System Console.

- manage_database fails at catalog time when the PostgreSQL version the
  catalog would install is below Mattermost's required 14 (EL platforms
  default older), with the postgresql::globals fix in the message.

### Changed

- Minimum supported Puppet/OpenVox raised from 7.24 to 8.0.
- Dropped Ubuntu 20.04 from supported platforms (EOL; default
  PostgreSQL below Mattermost's minimum).
