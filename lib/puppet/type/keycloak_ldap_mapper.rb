require_relative '../provider/keycloak_api'
require_relative '../../puppet_x/keycloak/type'
require_relative '../../puppet_x/keycloak/array_property'

Puppet::Type.newtype(:keycloak_ldap_mapper) do
  desc <<-DESC
Manage Keycloak LDAP attribute mappers
@example Add full name attribute mapping
  keycloak_ldap_mapper { 'full name for LDAP-test on test:
    ensure         => 'present',
    type           => 'full-name-ldap-mapper',
    ldap_attribute => 'gecos',
  }
  DESC

  extend PuppetX::Keycloak::Type
  add_autorequires

  ensurable

  newparam(:name, namevar: true) do
    desc 'The LDAP mapper name'
  end

  newparam(:id) do
    desc 'Id.'
  end

  newparam(:resource_name) do
    desc 'The LDAP mapper name. Defaults to `name`'
    defaultto do
      @resource[:name]
    end
  end

  newparam(:type) do
    desc 'providerId'
    newvalues('user-attribute-ldap-mapper', 'full-name-ldap-mapper')
    defaultto 'user-attribute-ldap-mapper'
    munge { |v| v }
  end

  newparam(:realm, namevar: true) do
    desc 'realm'
  end

  newparam(:ldap, namevar: true) do
    desc 'parentId'
  end

  newproperty(:ldap_attribute) do
    desc 'ldap.attribute'
  end

  newproperty(:user_model_attribute) do
    desc 'user.model.attribute'
  end

  newproperty(:is_mandatory_in_ldap) do
    desc 'is.mandatory.in.ldap. Defaults to `false` unless `type` is `full-name-ldap-mapper`.'
    defaultto do
      if @resource[:type] == 'full-name-ldap-mapper'
        nil
      else
        :false
      end
    end
  end

  newproperty(:always_read_value_from_ldap, boolean: true) do
    desc 'always.read.value.from.ldap. Defaults to `true` if `type` is `user-attribute-ldap-mapper`.'
    newvalues(:true, :false)
    defaultto do
      if @resource[:type] == 'user-attribute-ldap-mapper'
        :true
      else
        nil
      end
    end
  end

  newproperty(:read_only, boolean: true) do
    desc 'read.only'
    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:write_only, boolean: true) do
    desc 'write.only.  Defaults to `false` if `type` is `full-name-ldap-mapper`.'
    newvalues(:true, :false)
    defaultto do
      if @resource[:type] == 'full-name-ldap-mapper'
        :false
      else
        nil
      end
    end
  end

  autorequire(:keycloak_ldap_user_provider) do
    requires = []
    catalog.resources.each do |resource|
      next unless resource.class.to_s == 'Puppet::Type::Keycloak_ldap_user_provider'
      if self[:ldap] == "#{resource[:resource_name]}-#{resource[:realm]}"
        requires << resource.name
      end
    end
    requires
  end

  def self.title_patterns
    [
      [
        %r{^((.+) for (\S+) on (\S+))$},
        [
          [:name],
          [:resource_name],
          [:ldap],
          [:realm],
        ],
      ],
      [
        %r{(.*)},
        [
          [:name],
        ],
      ],
    ]
  end

  validate do
    required_properties = [
      :realm,
      :ldap,
    ]
    required_properties.each do |property|
      if self[property].nil?
        raise Puppet::Error, "You must provide a value for #{property}"
      end
    end
  end
end
