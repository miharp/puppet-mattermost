# frozen_string_literal: true

begin
  require 'voxpupuli/test/rake'
rescue LoadError
  # voxpupuli-test is only available in the test gem group
end

begin
  require 'voxpupuli/acceptance/rake'
  task beaker: 'fixtures:prep'
rescue LoadError
  # voxpupuli-acceptance is only available in the system_tests gem group
end

begin
  require 'puppet-strings/tasks'
rescue LoadError
  # openvox-strings is only available in the development gem group
end
