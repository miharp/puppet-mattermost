# puppet-mattermost

[![License](https://img.shields.io/github/license/miharp/puppet-mattermost.svg)](https://github.com/miharp/puppet-mattermost/blob/main/LICENSE)

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
  repository — and manages the `mattermost` system user and systemd unit
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
* On the RHEL family: the release tarball extracted to `/opt/mattermost`,
  the `mattermost` system user and group, and
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
owner — which on PostgreSQL 15+ also grants it the `public` schema). To
customize the PostgreSQL server itself, declare it before this class;
`mattermost` only `include`s it:

```puppet
class { 'postgresql::server':
  version => '16',
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

### Pinning a version

On Ubuntu, pin through the package:

```puppet
class { 'mattermost':
  site_url       => 'https://mattermost.example.com',
  db_password    => Sensitive('supersecret'),
  package_ensure => '10.5.1-0',
}
```

On the RHEL family the `version` parameter *is* the pin. To install from a
mirror instead of releases.mattermost.com, set `archive_source`.

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

* Ubuntu 20.04/22.04/24.04 and RHEL-family (RHEL, Rocky, AlmaLinux,
  Oracle Linux) 8/9 only (matching the upstream deployment guide). Debian
  support would need repository verification first.
* Tarball installs (`install_method => 'archive'`) do not upgrade in
  place: the archive only extracts when `/opt/mattermost/bin/mattermost`
  is absent. To upgrade, follow the [upstream upgrade
  procedure](https://docs.mattermost.com/deployment-guide/server/upgrade-mattermost.html)
  (or remove the old binaries) and raise `version`.
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
  out); all other settings remain console-editable and persist.

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
