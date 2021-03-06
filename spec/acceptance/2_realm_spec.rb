require 'spec_helper_acceptance'

describe 'keycloak_realm:' do
  context 'creates realm' do
    it 'should run successfully' do
      pp =<<-EOS
      include mysql::server
      class { 'keycloak':
        datasource_driver => 'mysql',
      }
      keycloak_realm { 'test': ensure => 'present' }
      EOS

      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    it 'should have created a realm' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get realms/test' do
        data = JSON.parse(stdout)
        expect(data['id']).to eq('test')
      end
    end

    it 'should have left default-client-scopes' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get realms/test/default-default-client-scopes' do
        data = JSON.parse(stdout)
        names = data.map { |d| d['name'] }.sort
        expect(names).to include('email')
        expect(names).to include('profile')
        expect(names).to include('role_list')
      end
    end

    it 'should have left optional-client-scopes' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get realms/test/default-optional-client-scopes' do
        data = JSON.parse(stdout)
        names = data.map { |d| d['name'] }.sort
        expect(names).to include('address')
        expect(names).to include('offline_access')
        expect(names).to include('phone')
      end
    end

    it 'should have default events config' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get events/config -r test' do
        data = JSON.parse(stdout)
        expect(data['eventsEnabled']).to eq(false)
        expect(data['eventsExpiration']).to be_nil
        expect(data['eventsListeners']).to eq([ "jboss-logging" ])
        expect(data['adminEventsEnabled']).to eq(false)
        expect(data['adminEventsDetailsEnabled']).to eq(false)
      end
    end
  end

  context 'updates realm' do
    it 'should run successfully' do
      pp =<<-EOS
      include mysql::server
      class { 'keycloak':
        datasource_driver => 'mysql',
      }
      keycloak_realm { 'test':
        ensure => 'present',
        remember_me => true,
        default_client_scopes => ['profile'],
        events_enabled => true,
        events_expiration => 2678400,
        admin_events_enabled => true,
        admin_events_details_enabled => true,
      }
      EOS

      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    it 'should have updated the realm' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get realms/test' do
        data = JSON.parse(stdout)
        expect(data['rememberMe']).to eq(true)
      end
    end

    it 'should have updated the realm default-client-scopes' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get realms/test/default-default-client-scopes' do
        data = JSON.parse(stdout)
        names = data.map { |d| d['name'] }
        expect(names).to eq(['profile'])
      end
    end

    it 'should have updated events config' do
      on hosts, '/opt/keycloak/bin/kcadm-wrapper.sh get events/config -r test' do
        data = JSON.parse(stdout)
        expect(data['eventsEnabled']).to eq(true)
        expect(data['eventsExpiration']).to eq(2678400)
        expect(data['eventsListeners']).to eq([ "jboss-logging" ])
        expect(data['adminEventsEnabled']).to eq(true)
        expect(data['adminEventsDetailsEnabled']).to eq(true)
      end
    end
  end
end
