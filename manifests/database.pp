# @summary Manages a local PostgreSQL server and the Mattermost database
#
# @api private
class mattermost::database {
  assert_private()

  if $mattermost::manage_database {
    # Mattermost requires PostgreSQL 14+, and several supported platforms
    # default older (EL8: 10, EL9: 13). Left unchecked, the catalog
    # applies cleanly and the mattermost service then fails at startup
    # with a database version error — fail at compile time with the fix
    # instead. NOTE: this checks the version the catalog would install;
    # it cannot see a wrong-version PostgreSQL already installed on the
    # host (see README Limitations).
    $pg_version = postgresql::default('version')
    if versioncmp(String($pg_version), '14') < 0 {
      fail(join([
        "mattermost: PostgreSQL ${pg_version} (this platform's default) is below ",
        "Mattermost's required minimum of 14. Declare postgresql::globals before this ",
        "class, e.g. class { 'postgresql::globals': manage_package_repo => true, ",
        "manage_dnf_module => true, version => '16' }",
      ], ''))
    }

    include postgresql::server

    # Encoding, locale and template follow the upstream database
    # preparation guide. Making the Mattermost user the database owner
    # also covers the PostgreSQL 15+ requirement that it own the public
    # schema (the schema belongs to the database owner since 15).
    postgresql::server::db { $mattermost::db_name:
      user     => $mattermost::db_user,
      password => postgresql::postgresql_password($mattermost::db_user, $mattermost::db_password),
      owner    => $mattermost::db_user,
      encoding => 'UTF8',
      locale   => 'en_US.UTF-8',
      template => 'template0',
    }
  }
}
