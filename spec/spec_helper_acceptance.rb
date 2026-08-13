# frozen_string_literal: true

require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker do |host|
  # The en_US.UTF-8 locale is required by the upstream database
  # preparation guide (CREATE DATABASE ... LC_COLLATE='en_US.UTF-8')
  # but is not generated on minimal images. curl is used by the
  # acceptance specs to probe the Mattermost API.
  case fact_on(host, 'os.family')
  when 'Debian'
    host.install_package('locales')
    host.install_package('curl')
    on host, 'locale-gen en_US.UTF-8'
  when 'RedHat'
    # curl is already provided by curl-minimal on EL9 (installing the
    # full curl package conflicts with it).
    host.install_package('glibc-langpack-en')
  end
end
