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
Ubuntu following the [official Linux deployment
guide](https://docs.mattermost.com/deployment-guide/server/deploy-linux.html):

* manages the `deb.packages.mattermost.com` apt repository
* installs the `mattermost` package
* renders `/opt/mattermost/config/config.json` (SiteURL, PostgreSQL
  DataSource, and anything else via `override_options`)
* manages the `mattermost` systemd service

The module has one area of responsibility — the Mattermost server. It does
**not** manage PostgreSQL or a reverse proxy; pair it with
`puppetlabs/postgresql` and an nginx module for a complete deployment.

## Setup

### What mattermost affects

* The apt source `mattermost` and its signing key (disable with
  `manage_repo => false`)
* The `mattermost` package
* `/opt/mattermost/config/config.json` — **owned by Puppet**; changes made
  through the Mattermost System Console are reverted on the next agent run
* The `mattermost` service

### Setup requirements

A reachable PostgreSQL (v14+) database with a user that owns it. For
example, on the same host with `puppetlabs/postgresql`:

```puppet
class { 'postgresql::server': }

postgresql::server::db { 'mattermost':
  user     => 'mmuser',
  password => postgresql::postgresql_password('mmuser', Sensitive('supersecret')),
}
```

### Beginning with mattermost

```puppet
class { 'mattermost':
  site_url    => 'https://mattermost.example.com',
  db_password => Sensitive('supersecret'),
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

### Arbitrary config.json settings

Any setting without a dedicated parameter can be set through
`override_options`, which is deep-merged over what the module renders:

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

```puppet
class { 'mattermost':
  site_url       => 'https://mattermost.example.com',
  db_password    => Sensitive('supersecret'),
  package_ensure => '10.5.1-0',
}
```

## Reference

See [REFERENCE.md](REFERENCE.md), generated with
[puppet-strings](https://github.com/puppetlabs/puppet-strings):

```console
bundle exec rake strings:generate:reference
```

## Limitations

* Ubuntu 20.04, 22.04 and 24.04 only (matching the upstream deployment
  guide). Debian support would need repository verification first.
* Because `config.json` is managed by Puppet, configuration via the System
  Console does not persist. Keep all settings in Puppet (see
  `override_options`).
* Mattermost fills in defaults for keys absent from `config.json`, so the
  rendered file intentionally contains only the settings you declare.

## Development

Pull requests welcome on
[GitHub](https://github.com/miharp/puppet-mattermost). Run the test suite
with:

```console
bundle install
bundle exec rake validate lint strings:validate:reference
bundle exec rake spec
```
