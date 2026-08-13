# frozen_string_literal: true

require 'spec_helper'

describe 'mattermost' do
  let(:params) do
    {
      site_url: 'https://mattermost.example.com',
      db_password: sensitive('supersecret'),
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      let(:env_file) do
        (os_facts[:os]['family'] == 'RedHat') ? '/etc/sysconfig/mattermost' : '/etc/default/mattermost'
      end

      let(:config_env) do
        content = catalogue.resource('file', env_file)[:content]
        content.respond_to?(:unwrap) ? content.unwrap : content
      end

      let(:params) { super().merge(version: '11.9.1') } if os_facts[:os]['family'] == 'RedHat'

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('mattermost::repo') }
      it { is_expected.to contain_class('mattermost::install') }
      it { is_expected.to contain_class('mattermost::database') }
      it { is_expected.to contain_class('mattermost::config') }
      it { is_expected.to contain_class('mattermost::service') }

      it { is_expected.not_to contain_class('postgresql::server') }
      it { is_expected.not_to contain_postgresql__server__db('mattermost') }

      it do
        expect(subject).to contain_file(env_file)
          .with_owner('root')
          .with_group('root')
          .with_mode('0600')
          .with_show_diff(false)
      end

      it 'renders the PostgreSQL DataSource and SiteURL as MM_* variables' do
        dsn = 'postgres://mmuser:supersecret@localhost:5432/mattermost?sslmode=disable&connect_timeout=10'
        expect(config_env).to include('MM_SQLSETTINGS_DRIVERNAME=postgres',
                                      "MM_SQLSETTINGS_DATASOURCE=#{dsn}",
                                      'MM_SERVICESETTINGS_SITEURL=https://mattermost.example.com')
      end

      it { is_expected.to contain_service('mattermost').with_ensure('running').with_enable(true) }

      context 'with service_manage => false' do
        let(:params) { super().merge(service_manage: false) }

        it { is_expected.not_to contain_service('mattermost') }
        it { is_expected.not_to contain_file('/etc/systemd/system/mattermost.service') }
        it { is_expected.not_to contain_file('/etc/systemd/system/mattermost.service.d/puppet.conf') }
      end

      context 'with override_options' do
        let(:params) do
          super().merge(override_options: {
                          'TeamSettings' => { 'SiteName' => 'ACME Chat', 'EnableOpenServer' => false },
                        })
        end

        it 'renders overrides as MM_* variables, JSON-encoding non-strings' do
          expect(config_env).to include('MM_TEAMSETTINGS_SITENAME=ACME Chat',
                                        'MM_TEAMSETTINGS_ENABLEOPENSERVER=false',
                                        'MM_SERVICESETTINGS_SITEURL=https://mattermost.example.com')
        end
      end

      context 'with manage_database => true' do
        let(:params) { super().merge(manage_database: true) }

        # EL platforms default to PostgreSQL < 14, so real usage declares
        # postgresql::globals first (as the acceptance suite does); the
        # Ubuntu defaults already satisfy Mattermost's minimum.
        if os_facts[:os]['family'] == 'RedHat'
          let(:pre_condition) do
            "class { 'postgresql::globals': manage_package_repo => true, manage_dnf_module => true, version => '16' }"
          end
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('postgresql::server') }

        it do
          expect(subject).to contain_postgresql__server__db('mattermost')
            .with(user: 'mmuser', owner: 'mmuser', encoding: 'UTF8',
                  locale: 'en_US.UTF-8', template: 'template0')
        end

        it 'orders the database before the service' do
          expect(subject).to contain_class('mattermost::database').that_comes_before('Class[mattermost::service]')
        end
      end

      context 'with support_email' do
        let(:params) { super().merge(support_email: 'support@example.com') }

        it 'sets SupportSettings.SupportEmail' do
          expect(config_env).to include('MM_SUPPORTSETTINGS_SUPPORTEMAIL=support@example.com')
        end
      end

      case os_facts[:os]['family']
      when 'Debian'
        it { is_expected.to contain_apt__source('mattermost').with_location('https://deb.packages.mattermost.com') }
        it { is_expected.to contain_package('mattermost').with_ensure('installed') }
        it { is_expected.not_to contain_archive('mattermost-11.9.1.tar.gz') }
        it { is_expected.not_to contain_user('mattermost') }
        it { is_expected.not_to contain_file('/etc/systemd/system/mattermost.service') }

        it 'adds the environment file to the packaged unit via a drop-in' do
          expect(subject).to contain_file('/etc/systemd/system/mattermost.service.d/puppet.conf')
            .with_content(%r{^EnvironmentFile=-/etc/default/mattermost$})
            .that_notifies('Service[mattermost]')
        end

        context 'with manage_repo => false' do
          let(:params) { super().merge(manage_repo: false) }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_apt__source('mattermost') }
        end
      when 'RedHat'
        it { is_expected.not_to contain_apt__source('mattermost') }
        it { is_expected.not_to contain_package('mattermost') }
        it { is_expected.not_to contain_file('/etc/systemd/system/mattermost.service.d/puppet.conf') }

        it do
          expect(subject).to contain_archive('mattermost-11.9.1.tar.gz')
            .with_source('https://releases.mattermost.com/11.9.1/mattermost-11.9.1-linux-amd64.tar.gz')
            .with_extract_path('/opt')
            .with_creates('/opt/mattermost/bin/mattermost')
        end

        it { is_expected.to contain_group('mattermost').with_system(true) }
        it { is_expected.to contain_user('mattermost').with_system(true).with_shell('/usr/sbin/nologin') }

        it do
          expect(subject).to contain_exec('mattermost-install-ownership')
            .with_refreshonly(true)
            .that_subscribes_to('Archive[mattermost-11.9.1.tar.gz]')
        end

        it do
          expect(subject).to contain_file('/opt/mattermost/data')
            .with_ensure('directory')
            .with_owner('mattermost')
            .with_group('mattermost')
        end

        it 'manages the systemd unit' do
          content = catalogue.resource('file', '/etc/systemd/system/mattermost.service')[:content]
          expect(content).to match(%r{^ExecStart=/opt/mattermost/bin/mattermost$})
          expect(content).to match(%r{^EnvironmentFile=-/etc/sysconfig/mattermost$})
          expect(content).to match(/^User=mattermost$/)
          expect(content).to match(%r{^WorkingDirectory=/opt/mattermost$})
        end

        it do
          expect(subject).to contain_file('/etc/systemd/system/mattermost.service')
            .that_notifies('Service[mattermost]')
        end

        context 'when on aarch64' do
          let(:facts) do
            os_facts.merge(os: os_facts[:os].merge('architecture' => 'aarch64'))
          end

          it do
            expect(subject).to contain_archive('mattermost-11.9.1.tar.gz')
              .with_source('https://releases.mattermost.com/11.9.1/mattermost-11.9.1-linux-arm64.tar.gz')
          end
        end

        context 'with archive_source' do
          let(:params) do
            super().merge(archive_source: 'https://mirror.example.com/mattermost-11.9.1-linux-amd64.tar.gz')
          end

          it do
            expect(subject).to contain_archive('mattermost-11.9.1.tar.gz')
              .with_source('https://mirror.example.com/mattermost-11.9.1-linux-amd64.tar.gz')
          end
        end

        context 'without version' do
          let(:params) { super().except(:version) }

          it { is_expected.to compile.and_raise_error(/'version' is required when install_method is 'archive'/) }
        end

        context 'with manage_repo => true' do
          let(:params) { super().merge(manage_repo: true) }

          it { is_expected.to compile.and_raise_error(/no package repository for the RedHat family/) }
        end

        context 'with manage_database => true and no postgresql::globals' do
          let(:params) { super().merge(manage_database: true) }

          it "fails on the platform's default PostgreSQL being too old" do
            expect(subject).to compile.and_raise_error(/below Mattermost's required minimum of 14/)
          end
        end
      end
    end
  end
end
