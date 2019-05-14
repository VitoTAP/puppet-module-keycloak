require File.expand_path(File.join(File.dirname(__FILE__), '..', 'keycloak_api'))

Puppet::Type.type(:keycloak_ldap_mapper).provide(:kcadm, parent: Puppet::Provider::KeycloakAPI) do
  desc ''

  mk_resource_methods

  def self.instances
    components = []
    realms.each do |realm|
      output = kcadm('get', 'components', realm)
      Puppet.debug("#{realm} components: #{output}")
      begin
        data = JSON.parse(output)
      rescue JSON::ParserError
        Puppet.debug('Unable to parse output from kcadm get components')
        data = []
      end

      data.each do |d|
        next unless d['providerType'] == 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper'
        next unless d['providerId'] == 'user-attribute-ldap-mapper' || d['providerId'] == 'full-name-ldap-mapper'
        component = {}
        component[:ensure] = :present
        component[:id] = d['id']
        component[:realm] = realm
        component[:resource_name] = d['name']
        component[:ldap] = d['parentId']
        component[:type] = d['providerId']
        component[:name] = "#{component[:resource_name]} for #{component[:ldap]} on #{component[:realm]}"
        type_properties.each do |property|
          key = if property == :ldap_attribute && component[:type] == 'full-name-ldap-mapper'
                  'ldap.full.name.attribute'
                else
                  property.to_s.tr('_', '.')
                end
          next unless d['config'].key?(key)
          value = d['config'][key][0]
          if !!value == value # rubocop:disable Style/DoubleNegation
            value = value.to_s.to_sym
          end
          component[property.to_sym] = value
        end
        components << new(component)
      end
    end
    components
  end

  def self.prefetch(resources)
    components = instances
    resources.keys.each do |name|
      provider = components.find do |c|
        c.resource_name == resources[name][:resource_name] &&
          c.realm == resources[name][:realm] &&
          c.ldap == resources[name][:ldap]
      end
      next unless provider
      resources[name].provider = provider
    end
  end

  def create
    data = {}
    data[:id] = resource[:id] || name_uuid(resource[:name])
    data[:name] = resource[:resource_name]
    data[:parentId] = resource[:ldap]
    data[:providerId] = resource[:type]
    data[:providerType] = 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper'
    data[:config] = {}
    type_properties.each do |property|
      next unless resource[property.to_sym]
      key = if property == :ldap_attribute && resource[:type] == 'full-name-ldap-mapper'
              'ldap.full.name.attribute'
            else
              property.to_s.tr('_', '.')
            end
      # is.mandatory.in.ldap and user.model.attribute only belong to user-attribute-ldap-mapper
      if resource[:type] != 'user-attribute-ldap-mapper'
        if [:is_mandatory_in_ldap, :user_model_attribute, :always_read_value_from_ldap].include?(property)
          next
        end
      end
      # write.only only belongs to full-name-ldap-mapper
      if resource[:type] != 'full-name-ldap-mapper'
        if property == :write_only
          next
        end
      end
      data[:config][key] = [resource[property.to_sym]]
    end

    t = Tempfile.new('keycloak_component')
    t.write(JSON.pretty_generate(data))
    t.close
    Puppet.debug(IO.read(t.path))
    begin
      kcadm('create', 'components', resource[:realm], t.path)
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "kcadm create component failed\nError message: #{e.message}"
    end
    @property_hash[:ensure] = :present
  end

  def destroy
    begin
      kcadm('delete', "components/#{id}", resource[:realm])
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "kcadm delete realm failed\nError message: #{e.message}"
    end

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  type_properties.each do |prop|
    define_method "#{prop}=".to_sym do |value|
      @property_flush[prop] = value
    end
  end

  def flush
    unless @property_flush.empty?
      data = {}
      data[:providerId] = resource[:type]
      data[:providerType] = 'org.keycloak.storage.ldap.mappers.LDAPStorageMapper'
      data[:config] = {}
      type_properties.each do |property|
        next unless @property_flush[property.to_sym]
        key = if property == :ldap_attribute && resource[:type] == 'full-name-ldap-mapper'
                'ldap.full.name.attribute'
              else
                property.to_s.tr('_', '.')
              end
        # is.mandatory.in.ldap and user.model.attribute only belong to user-attribute-ldap-mapper
        if resource[:type] != 'user-attribute-ldap-mapper'
          if [:is_mandatory_in_ldap, :user_model_attribute, :always_read_value_from_ldap].include?(property)
            next
          end
        end
        # write.only only belongs to full-name-ldap-mapper
        if resource[:type] != 'full-name-ldap-mapper'
          if property == :write_only
            next
          end
        end
        data[:config][key] = [resource[property.to_sym]]
      end

      t = Tempfile.new('keycloak_component')
      t.write(JSON.pretty_generate(data))
      t.close
      Puppet.debug(IO.read(t.path))
      begin
        kcadm('update', "components/#{id}", resource[:realm], t.path)
      rescue Puppet::ExecutionFailure => e
        raise Puppet::Error, "kcadm update component failed\nError message: #{e.message}"
      end
    end
    # Collect the resources again once they've been changed (that way `puppet
    # resource` will show the correct values after changes have been made).
    @property_hash = resource.to_hash
  end
end
