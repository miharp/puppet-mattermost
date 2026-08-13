# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'mattermost' do
  # Several supported platforms ship a PostgreSQL older than the v14
  # Mattermost requires (EL8: 10, EL9: 13, Ubuntu 20.04: 12), so the
  # acceptance manifest takes PostgreSQL 16 from the PGDG repository.
  # version is only used by the archive install method (RedHat family);
  # Debian-family hosts install the latest package from the apt repo.
  let(:manifest) do
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
        #{"version         => '11.9.1'," if redhat}
      }
    PUPPET
  end

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
end
