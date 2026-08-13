# frozen_string_literal: true

require 'voxpupuli/test/rake'

begin
  require 'voxpupuli/acceptance/rake'
  task beaker: 'fixtures:prep'
rescue LoadError
  # voxpupuli-acceptance is optional (system_tests group)
end

begin
  require 'puppet-strings/tasks'
rescue LoadError
  # openvox-strings is optional (development group)
end
