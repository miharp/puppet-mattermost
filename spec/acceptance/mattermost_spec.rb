# frozen_string_literal: true

require 'spec_helper_acceptance'

MATTERMOST_INITIAL_VERSION = '11.9.1'
MATTERMOST_UPGRADE_VERSION = '11.10.1'

# Several supported platforms ship a PostgreSQL older than the v14
# Mattermost requires (EL8: 10, EL9: 13), so the acceptance manifest
# takes PostgreSQL 16 from the PGDG repository. version is only used by
# the archive install method (RedHat family); Debian-family hosts
# install the latest package from the apt repo.
def mattermost_manifest(version)
  redhat = fact('os.family') == 'RedHat'
  <<~PUPPET
    class { 'postgresql::globals':
      manage_package_repo => true,
      #{'manage_dnf_module   => true,' if redhat}
      version             => '16',
    }

    class { 'mattermost':
      site_url        => 'http://localhost:8065',
      db_password     => Sensitive('acceptance-test-secret'),
      manage_database => true,
      #{"version         => '#{version}'," if redhat}
    }
  PUPPET
end

describe 'mattermost' do
  let(:manifest) { mattermost_manifest(MATTERMOST_INITIAL_VERSION) }

  it_behaves_like 'an idempotent resource'

  env_file = (fact('os.family') == 'RedHat') ? '/etc/sysconfig/mattermost' : '/etc/default/mattermost'

  describe file(env_file) do
    it { is_expected.to be_file }
    it { is_expected.to be_owned_by 'root' }
    it { is_expected.to be_mode 600 }
  end

  describe service('mattermost') do
    it { is_expected.to be_running }
    it { is_expected.to be_enabled }
  end

  describe 'the Mattermost API' do
    it 'answers the ping endpoint' do
      # Mattermost runs database migrations after service start, so poll
      # until it listens.
      ping = 'curl --silent --fail http://127.0.0.1:8065/api/v4/system/ping'
      result = shell("for i in $(seq 1 60); do #{ping} && exit 0; sleep 2; done; exit 1")
      expect(result.stdout).to include('"status"')
    end
  end

  describe port(8065) do
    it { is_expected.to be_listening }
  end

  if fact('os.family') == 'RedHat'
    describe 'the versioned tarball layout' do
      describe file("/opt/mattermost-#{MATTERMOST_INITIAL_VERSION}/bin/mattermost") do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'mattermost' }
      end

      describe file('/opt/mattermost') do
        it { is_expected.to be_symlink }
        it { is_expected.to be_linked_to "/opt/mattermost-#{MATTERMOST_INITIAL_VERSION}" }
      end

      describe file('/var/lib/mattermost') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'mattermost' }
      end

      # Mattermost creates config.json at MM_CONFIG on first start.
      describe file('/etc/mattermost/config.json') do
        it { is_expected.to be_owned_by 'mattermost' }

        its(:content) { is_expected.to include('"ServiceSettings"') }
      end
    end

    describe 'upgrading by raising version' do
      it 'installs the new version idempotently' do
        upgrade = mattermost_manifest(MATTERMOST_UPGRADE_VERSION)
        apply_manifest(upgrade, catch_failures: true)
        expect(apply_manifest(upgrade, catch_changes: true).exit_code).to eq(0)
      end

      it 'flips the symlink and keeps the previous version for rollback' do
        expect(file('/opt/mattermost')).to be_linked_to "/opt/mattermost-#{MATTERMOST_UPGRADE_VERSION}"
        expect(file("/opt/mattermost-#{MATTERMOST_INITIAL_VERSION}/bin/mattermost")).to be_file
        expect(file('/etc/mattermost/config.json')).to be_file
      end

      it 'runs the new version' do
        ping = 'curl --silent --fail http://127.0.0.1:8065/api/v4/system/ping'
        result = shell("for i in $(seq 1 60); do #{ping} && exit 0; sleep 2; done; exit 1")
        expect(result.stdout).to include('"status"')
        version = shell('/opt/mattermost/bin/mattermost version 2>/dev/null')
        expect(version.stdout).to include("Version: #{MATTERMOST_UPGRADE_VERSION}")
      end
    end
  end
end
