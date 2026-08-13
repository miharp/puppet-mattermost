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

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('mattermost::repo') }
      it { is_expected.to contain_class('mattermost::install') }
      it { is_expected.to contain_class('mattermost::config') }
      it { is_expected.to contain_class('mattermost::service') }

      it { is_expected.to contain_apt__source('mattermost').with_location('https://deb.packages.mattermost.com') }
      it { is_expected.to contain_package('mattermost').with_ensure('installed') }

      it do
        is_expected.to contain_file('/opt/mattermost/config/config.json')
          .with_owner('mattermost')
          .with_group('mattermost')
          .with_mode('0600')
          .with_show_diff(false)
      end

      it 'renders the PostgreSQL DataSource' do
        content = catalogue.resource('file', '/opt/mattermost/config/config.json')[:content].unwrap
        config = JSON.parse(content)
        expect(config['SqlSettings']['DriverName']).to eq('postgres')
        expect(config['SqlSettings']['DataSource'])
          .to eq('postgres://mmuser:supersecret@localhost:5432/mattermost?sslmode=disable&connect_timeout=10')
        expect(config['ServiceSettings']['SiteURL']).to eq('https://mattermost.example.com')
      end

      it { is_expected.to contain_service('mattermost').with_ensure('running').with_enable(true) }

      context 'with manage_repo => false' do
        let(:params) { super().merge(manage_repo: false) }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_apt__source('mattermost') }
      end

      context 'with service_manage => false' do
        let(:params) { super().merge(service_manage: false) }

        it { is_expected.not_to contain_service('mattermost') }
      end

      context 'with override_options' do
        let(:params) do
          super().merge(override_options: { 'TeamSettings' => { 'SiteName' => 'ACME Chat' } })
        end

        it 'deep merges into config.json' do
          content = catalogue.resource('file', '/opt/mattermost/config/config.json')[:content].unwrap
          config = JSON.parse(content)
          expect(config['TeamSettings']['SiteName']).to eq('ACME Chat')
          expect(config['ServiceSettings']['SiteURL']).to eq('https://mattermost.example.com')
        end
      end

      context 'with support_email' do
        let(:params) { super().merge(support_email: 'support@example.com') }

        it 'sets SupportSettings.SupportEmail' do
          content = catalogue.resource('file', '/opt/mattermost/config/config.json')[:content].unwrap
          config = JSON.parse(content)
          expect(config['SupportSettings']['SupportEmail']).to eq('support@example.com')
        end
      end
    end
  end
end
