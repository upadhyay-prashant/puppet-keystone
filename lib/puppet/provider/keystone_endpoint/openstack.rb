require 'puppet/provider/keystone'

Puppet::Type.type(:keystone_endpoint).provide(
  :openstack,
  :parent => Puppet::Provider::Keystone
) do

  desc "Provider to manage keystone endpoints."

  @credentials = Puppet::Provider::Openstack::CredentialsV3.new

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def create
    properties = []
    # The region property is just ignored. We should fix this in kilo.
    region, name = resource[:name].split('/')
    properties << name
    properties << '--region'
    properties << region
    if resource[:public_url]
      temp = []
      temp << 'public'
      temp << resource[:public_url]
      pra = []
      pra << properties
      pra << temp
      self.class.request('endpoint', 'create', pra)
    end
    if resource[:internal_url]
      temp = []
      temp << 'internal'
      temp << resource[:internal_url]
      pra = []
      pra << properties
      pra << temp
      self.class.request('endpoint', 'create', pra)
    end
    if resource[:admin_url]
      temp = []
      temp << 'admin'
      temp << resource[:admin_url]
      pra = []
      pra << properties
      pra << temp
      self.class.request('endpoint', 'create', pra)
    end
     #self.class.request('endpoint', 'create', properties)
     @property_hash[:ensure] = :present
  end

  def destroy
# i could have added logic to selectively delete, for the time being taking easier way to delete all and create all 
    self.class.request('endpoint', 'delete', @property_hash[:id_admin])
    self.class.request('endpoint', 'delete', @property_hash[:id_internal])
    self.class.request('endpoint', 'delete', @property_hash[:id_public])
    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def region
    @property_hash[:region]
  end

  def public_url=(value)
    @property_flush[:public_url] = value
  end

  def public_url
    @property_hash[:public_url]
  end

  def internal_url=(value)
    @property_flush[:internal_url] = value
  end

  def internal_url
    @property_hash[:internal_url]
  end

  def admin_url=(value)
    @property_flush[:admin_url] = value
  end

  def admin_url
    @property_hash[:admin_url]
  end

  def id_internal
    @property_hash[:id_internal]
  end
  def id_admin
    @property_hash[:id_admin]
  end
  def id_public
    @property_hash[:id_public]
  end

  def self.instances
    list = request('endpoint', 'list')
    #print list
    pr_list= []
    require 'set'
    s1=Set.new
    list.collect do |endpoint|
      pr=list.select { |temp| temp[:service_name].casecmp(endpoint[:service_name])==0}
      pr.sort! { | temp, temp1| temp[:interface].casecmp(temp1[:interface])}
      s1.add(pr)
      end
    res=[]
    s1.each {|element|
      endpoint = {}
      element.each { |temp|
       endpoint[:name] = "#{temp[:region]}/#{temp[:service_name]}"
       endpoint[:region] = temp[:region]
       role=temp[:interface]
       endpoint[(role.to_s+"_url").intern] = temp[:url]
# id needs to be fixed here
       endpoint[("id_"+role.to_s).intern] = temp[:id]
      }
      res << new(
        :name         => endpoint[:name],
        :ensure       => :present,
        :id_admin     => endpoint[:id],
        :id_public    => endpoint[:id],
        :id_internal  => endpoint[:id],
        :region       => endpoint[:region],
        :public_url   => endpoint[:public_url],
        :internal_url => endpoint[:internal_url],
        :admin_url    => endpoint[:admin_url]
      )
    }
  return res
  end

  def self.prefetch(resources)
    endpoints = instances
    resources.keys.each do |name|
       if provider = endpoints.find{ |endpoint| endpoint.name == name }
        resources[name].provider = provider
      end
    end
  end

  def flush
    if ! @property_flush.empty?
      destroy
      create
      @property_flush.clear
    end
  end
end
