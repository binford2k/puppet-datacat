module Puppet_X
  module Richardc
    class Datacat
      def self.deep_merge
        deep_merge = Proc.new do |key,oldval,newval|
          newval.is_a?(Hash) && oldval.is_a?(Hash) ?
            oldval.merge(newval, &deep_merge) :
              newval.is_a?(Array) && oldval.is_a?(Array) ?
                oldval + newval :
                newval
        end
      end

      def self.encrypt(data, destination)
        raise Puppet::ArgumentError, 'Can only encrypt strings' unless data.class == String
        raise Puppet::ArgumentError, 'Need a node name to encrypt for' unless destination.class == String

        ssldir = Puppet.settings[:ssldir]
        cert   = OpenSSL::X509::Certificate.new(File.read("#{ssldir}/ca/ca_crt.pem"))
        key    = OpenSSL::PKey::RSA.new(File.read("#{ssldir}/ca/ca_key.pem"), '')
        target = OpenSSL::X509::Certificate.new(File.read("#{ssldir}/ca/signed/#{destination}.pem"))

        signed = OpenSSL::PKCS7::sign(cert, key, data, [], OpenSSL::PKCS7::BINARY)
        cipher = OpenSSL::Cipher::new("AES-128-CFB")

        OpenSSL::PKCS7::encrypt([target], signed.to_der, cipher, OpenSSL::PKCS7::BINARY).to_s
      end

      def self.decrypt(data)
        raise Puppet::ArgumentError, 'Can only decrypt strings' unless data.class == String

        ssldir = Puppet.settings[:ssldir]
        name   = Puppet.settings[:certname]
        cert   = OpenSSL::X509::Certificate.new(File.read("#{ssldir}/certs/#{name}.pem"))
        key    = OpenSSL::PKey::RSA.new(File.read("#{ssldir}/private_keys/#{name}.pem"), '')
        source = OpenSSL::X509::Certificate.new(File.read("#{ssldir}/certs/ca.pem"))

        store = OpenSSL::X509::Store.new
        store.add_cert(source)

        blob      = OpenSSL::PKCS7.new(data)
        decrypted = blob.decrypt(key, cert)
        verified  = OpenSSL::PKCS7.new(decrypted)

        verified.verify(nil, store, nil, OpenSSL::PKCS7::NOVERIFY)
        verified.data
      end
    end

    # Our much simpler version of Puppet::Parser::TemplateWrapper
    class Datacat_Binding
      def initialize(d, template)
        @data = d
        @__file__ = template
      end

      def file
        @__file__
      end

      # Find which line in the template (if any) we were called from.
      # @return [String] the line number
      # @api private
      def script_line
        identifier = Regexp.escape(@__file__ || "(erb)")
        (caller.find { |l| l =~ /#{identifier}:/ }||"")[/:(\d+):/,1]
      end
      private :script_line

      def method_missing(name, *args)
        line_number = script_line
        raise "Could not find value for '#{name}' #{@__file__}:#{line_number}"
      end

      def get_binding
        binding()
      end
    end
  end
end
