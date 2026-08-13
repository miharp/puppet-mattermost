# @summary Manages a local PostgreSQL server and the Mattermost database
#
# @api private
class mattermost::database {
  assert_private()

  if $mattermost::manage_database {
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
