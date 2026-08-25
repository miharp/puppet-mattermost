# puppet-mattermost

[![CI](https://github.com/miharp/puppet-mattermost/actions/workflows/ci.yml/badge.svg)](https://github.com/miharp/puppet-mattermost/actions/workflows/ci.yml)
[![OpenVox compatible](https://img.shields.io/badge/OpenVox-%3E%3D%208.0-orange.svg)](https://voxpupuli.org/openvox/)
[![License](https://img.shields.io/github/license/miharp/puppet-mattermost)](https://github.com/miharp/puppet-mattermost/blob/main/LICENSE)

[![Puppet Forge](https://img.shields.io/puppetforge/v/miharp/mattermost)](https://forge.puppet.com/modules/miharp/mattermost)
[![Puppet Forge downloads](https://img.shields.io/puppetforge/dt/miharp/mattermost)](https://forge.puppet.com/modules/miharp/mattermost)

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage](#usage)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Development](#development)

## Description

Installs and configures a [Mattermost](https://mattermost.com/) server on
Ubuntu and RHEL-family systems following the [official Linux deployment
guide](https://docs.mattermost.com/deployment-guide/server/deploy-linux.html):

* on Ubuntu, manages the `deb.packages.mattermost.com` apt repository and
  installs the `mattermost` package
* on the RHEL family (RHEL, Rocky, AlmaLinux, Oracle Linux 8/9), installs
  from the official release tarball — Mattermost publishes no yum/dnf
  repository — into a versioned directory, and manages the `mattermost`
  system user and systemd unit; raising `version` upgrades in place
* manages Mattermost settings (SiteURL, PostgreSQL DataSource, and
  anything else via `override_options`) as `MM_*` environment variables
  in an environment file loaded by the systemd unit
* manages the `mattermost` systemd service

The module's primary responsibility is the Mattermost server. For
single-host deployments it can also create the PostgreSQL database and
user (`manage_database => true`, using `puppetlabs/postgresql` per the
[upstream database preparation
guide](https://docs.mattermost.com/deployment-guide/server/preparations.html#database-preparation)).
It does **not** manage a reverse proxy; pair it with an nginx module for
a complete deployment.

## Setup

### What mattermost affects

* On Ubuntu: the apt source `mattermost` and its signing key (disable with
  `manage_repo => false`) and the `mattermost` package
* On the RHEL family: the release tarball extracted to
  `/opt/mattermost-<version>` with `/opt/mattermost` a symlink to it,
  the data directory `/var/lib/mattermost` (`data_dir`), the directory
  of `/etc/mattermost/config.json` (`config_file`, passed to Mattermost
  as `MM_CONFIG`), the `mattermost` system user and group, and
  `/etc/systemd/system/mattermost.service`
* An environment file (`/etc/default/mattermost` on Debian,
  `/etc/sysconfig/mattermost` on RHEL) with `MM_*` variables, hooked
  into the systemd unit (via a drop-in for the packaged unit).
  Mattermost gives environment variables precedence over `config.json`,
  so Puppet-managed settings always win, while settings the module does
  not manage remain editable in the System Console and persist.
  `config.json` itself is left to Mattermost, which rewrites it at
  startup — managing it directly would revert it (and restart the
  service) on every agent run.
* The `mattermost` service

### Setup requirements

A reachable PostgreSQL (v14+) database with a user that owns it. For a
database on the same host, the module can manage it for you:

```puppet
class { 'mattermost':
  site_url        => 'https://mattermost.example.com',
  db_password     => Sensitive('supersecret'),
  manage_database => true,
}
```

This installs a PostgreSQL server with `puppetlabs/postgresql` defaults
and creates the database and user following the upstream preparation
guide (UTF8 encoding from `template0`, the Mattermost user as database
owner — which on PostgreSQL 15+ also grants it the `public` schema).

Mattermost requires PostgreSQL 14+, and the module fails at catalog time
if the version being installed is older. Several platforms default older
(EL8: 10, EL9: 13), so on the RHEL family declare `postgresql::globals`
before this class:

```puppet
class { 'postgresql::globals':
  manage_package_repo => true,
  manage_dnf_module   => true,
  version             => '16',
}

class { 'mattermost':
  site_url        => 'https://mattermost.example.com',
  db_password     => Sensitive('supersecret'),
  manage_database => true,
}
```

For a remote database, leave `manage_database => false` (the default)
and point the `db_*` parameters at it.

### Beginning with mattermost

On Ubuntu:

```puppet
class { 'mattermost':
  site_url    => 'https://mattermost.example.com',
  db_password => Sensitive('supersecret'),
}
```

On the RHEL family, `version` is required because the tarball URL is
version-specific:

```puppet
class { 'mattermost':
  site_url    => 'https://mattermost.example.com',
  db_password => Sensitive('supersecret'),
  version     => '11.9.1',
}
```

## Usage

### Remote database and support email

```puppet
class { 'mattermost':
  site_url      => 'https://mattermost.example.com',
  db_host       => 'db.example.com',
  db_user       => 'mmuser',
  db_password   => Sensitive('supersecret'),
  db_sslmode    => 'require',
  support_email => 'support@example.com',
}
```

### Arbitrary Mattermost settings

Any setting without a dedicated parameter can be set through
`override_options`, expressed as config.json-style sections and
deep-merged over what the module manages (each entry becomes an `MM_*`
environment variable):

```puppet
class { 'mattermost':
  site_url         => 'https://mattermost.example.com',
  db_password      => Sensitive('supersecret'),
  override_options => {
    'TeamSettings' => {
      'SiteName'                => 'ACME Chat',
      'EnableOpenServer'        => false,
    },
    'FileSettings' => {
      'Directory' => '/srv/mattermost/data',
    },
  },
}
```

### Pinning and upgrading

On Ubuntu, pin through the package:

```puppet
class { 'mattermost':
  site_url       => 'https://mattermost.example.com',
  db_password    => Sensitive('supersecret'),
  package_ensure => '10.5.1-0',
}
```

On the RHEL family the `version` parameter *is* the pin, and raising it
upgrades Mattermost: the new tarball is extracted to
`/opt/mattermost-<new version>`, the `/opt/mattermost` symlink is
pointed at it, and the service is restarted (Mattermost runs its
database migrations on start). `config.json` and uploaded files live
outside the versioned directory (`/etc/mattermost/config.json` and
`/var/lib/mattermost` by default; see `config_file` and `data_dir`), so
System Console changes and data carry over. The previous
`/opt/mattermost-<old version>` is left in place for rollback — lower
`version` to go back — and can be deleted once you are happy with the
upgrade. Mattermost only supports [certain upgrade
paths](https://docs.mattermost.com/deployment-guide/server/upgrade-mattermost.html);
back up the database before upgrading.

To install from a mirror instead of releases.mattermost.com, set
`archive_source`.

### Migrating a tarball install from module 0.1.0

Module 0.1.0 extracted the tarball directly to `/opt/mattermost` with
`config.json` and `data` inside it. Puppet will not replace that
directory with a symlink (it fails rather than deleting it), so move it
into the versioned layout once, with the service stopped:

```console
systemctl stop mattermost
mv /opt/mattermost /opt/mattermost-11.9.1          # the installed version
mkdir /etc/mattermost /var/lib/mattermost
mv /opt/mattermost-11.9.1/config/config.json /etc/mattermost/
mv /opt/mattermost-11.9.1/data/* /var/lib/mattermost/
chown -R mattermost:mattermost /etc/mattermost /var/lib/mattermost
```

The next agent run creates the symlink, adds `MM_CONFIG` and
`MM_FILESETTINGS_DIRECTORY` to the environment file, and starts the
service.

### Tarball installs on other platforms

The `install_method` parameter defaults per OS family (`package` on
Debian, `archive` on RedHat) but can be forced, e.g. to do a tarball
install on Ubuntu:

```puppet
class { 'mattermost':
  site_url       => 'https://mattermost.example.com',
  db_password    => Sensitive('supersecret'),
  install_method => 'archive',
  manage_repo    => false,
  manage_user    => true,
  version        => '11.9.1',
}
```

## Reference

See [REFERENCE.md](REFERENCE.md), generated with
[puppet-strings](https://github.com/puppetlabs/puppet-strings):

```console
bundle exec rake strings:generate:reference
```

## Limitations

* Ubuntu 22.04/24.04 and RHEL-family (RHEL, Rocky, AlmaLinux,
  Oracle Linux) 8/9 only. (Ubuntu 20.04 is EOL and its PostgreSQL is
  older than Mattermost supports.) Debian support would need repository
  verification first.
* The PostgreSQL version check guards what the catalog would *install*;
  it cannot see a wrong-version PostgreSQL already present on the host.
  dnf module streams reuse the `postgresql-server` package name, so on a
  host that already has an older PostgreSQL installed, the package
  resource is satisfied and the old version stays. Remove the old
  packages and data directory (or upgrade manually) before enabling
  `manage_database` on such a host.
* Tarball installs keep every `/opt/mattermost-<version>` directory
  ever installed; the module never deletes old versions. Logs and
  plugin working directories live inside the versioned directory, so
  after an upgrade `/opt/mattermost/logs` starts fresh (the old logs
  remain under the previous version's directory).
* The apt repository only publishes amd64 packages, so arm64
  Debian-family hosts must use `install_method => 'archive'`. The
  archive method picks the matching amd64/arm64 tarball automatically.
* On RHEL the module does not configure firewalld (you will need a rule
  for port 8065) or fapolicyd. Default SELinux enforcing works without
  any relabeling — verified on EL9 with zero AVC denials — despite the
  upstream guide's `semanage fcontext` instructions; hardened (e.g.
  STIG/fapolicyd) environments may still need site-specific policy.
* Settings managed by Puppet are pinned via environment variables and
  cannot be changed through the System Console (Mattermost greys them
  out); all other settings remain console-editable and persist. For
  tarball installs this includes `FileSettings.Directory` (`data_dir`).

## Development

Pull requests welcome on
[GitHub](https://github.com/miharp/puppet-mattermost). Run the unit test
suite and static checks with:

```console
bundle install
bundle exec rake validate lint check rubocop
bundle exec rake spec
```

Acceptance tests use [Beaker](https://github.com/voxpupuli/beaker) via
[voxpupuli-acceptance](https://github.com/voxpupuli/voxpupuli-acceptance),
following the [OpenVox acceptance testing
guide](https://docs.openvoxproject.org/ecosystem/latest/devkit/acceptance_testing.html).
They apply the module (with `manage_database => true`) to a systemd
container, verify idempotency, and probe the live API:

```console
BEAKER_SETFILE=ubuntu2404-64 BEAKER_PUPPET_COLLECTION=openvox8 bundle exec rake beaker
BEAKER_SETFILE=almalinux9-64 BEAKER_PUPPET_COLLECTION=openvox8 bundle exec rake beaker
```

On Apple Silicon, also set `DOCKER_DEFAULT_PLATFORM=linux/amd64` (the
Mattermost packages and tarballs are amd64) and, if needed,
`DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`.

CI runs the same checks through the
[voxpupuli/gha-puppet](https://github.com/voxpupuli/gha-puppet) reusable
workflow, which builds its acceptance matrix from `metadata.json` and
tests against the OpenVox 8 collection.
