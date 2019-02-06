require 'redis-store'

module I18n
  module Backend
    class Redis
      include Flatten
      include Base
      attr_accessor :store

      # Instantiate the store.
      #
      # Example:
      #   RedisStore.new
      #     # => host: localhost,   port: 6379,  db: 0
      #
      #   RedisStore.new "example.com"
      #     # => host: example.com, port: 6379,  db: 0
      #
      #   RedisStore.new "example.com:23682"
      #     # => host: example.com, port: 23682, db: 0
      #
      #   RedisStore.new "example.com:23682/1"
      #     # => host: example.com, port: 23682, db: 1
      #
      #   RedisStore.new "example.com:23682/1/theplaylist"
      #     # => host: example.com, port: 23682, db: 1, namespace: theplaylist
      #
      #   RedisStore.new "localhost:6379/0", "localhost:6380/0"
      #     # => instantiate a cluster
      def initialize(*addresses)
        @store = ::Redis::Store::Factory.create(addresses)
      end

      def translate(locale, key, options = {})
        options[:resolve] ||= false
        super locale, key, options
      end

      def store_translations(locale, data, options = {})
        escape = options.fetch(:escape, true)
        flatten_translations(locale, data, escape, false).each do |key, value|
          case value
          when Proc
            raise 'Key-value stores cannot handle procs'
          else
            @store.set "#{locale}.#{key}", value.to_json
          end
        end
      end

      def available_locales
        locales = @store.keys.map do |k|
          k =~ /\./
          $`
        end
        locales.uniq!
        locales.compact!
        locales.map!(&:to_sym)
        locales
      end

      protected

      # rubocop:disable Metrics/MethodLength
      def lookup(locale, key, scope = [], options = {})
        key = normalize_flat_keys(locale, key, scope, options[:separator])

        main_key = "#{locale}.#{key}"
        if (result = @store.get(main_key))
          return JSON.parse(result)
        end

        child_keys = @store.keys("#{main_key}.*")
        return nil if child_keys.empty?

        result = {}
        subkey_part = (main_key.size + 1)..-1
        child_keys.each do |child_key|
          subkey         = child_key[subkey_part].to_sym
          result[subkey] = @store.get child_key
        end

        result
      end
      # rubocop:enable Metrics/MethodLength

      def resolve_link(_locale, key)
        key
      end
    end
  end
end
