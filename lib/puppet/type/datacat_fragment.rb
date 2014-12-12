Puppet::Type.newtype(:datacat_fragment) do
  desc 'A fragment of data for a datacat resource.'

  newparam(:name, :namevar => true) do
    desc 'The name of this fragment.'
  end

  newparam(:target) do
    desc 'The title of the datacat resource that the data should be considered part of.  May be an array to indicate multiple targetted collectors.'
  end

  newparam(:order) do
    desc 'The order in which to merge this fragment into the datacat resource.  Defaults to the string "50"'
    defaultto "50"
  end

  newparam(:data) do
    desc 'A hash of data to be merged for this resource.'
  end

  newparam(:encrypted) do
    desc 'Whether the data values should be encrypted over the wire.'
    newvalues(:true, :false)
    defaultto :false
  end

  validate do
    if self[:encrypted] == :true
      self[:data].each do |key,value|
        # using the fqdn is a terrible idea, but I couldn't figure out how to get clientcert here
        self[:data][key] = Puppet_X::Richardc::Datacat.encrypt(value, Facter.value(:fqdn))
      end
    end
  end
end
