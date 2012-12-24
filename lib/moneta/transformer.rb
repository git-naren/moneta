module Moneta
  # Transforms keys and values (Marshal, YAML, JSON, Base64, MD5, ...).
  # You can bypass the transformer (e.g. serialization) by using the `:raw` option.
  #
  # @example Add `Moneta::Transformer` to proxy stack
  #   Moneta.build do
  #     transformer :key => [:marshal, :escape], :value => [:marshal]
  #     adapter :File, :dir => 'data'
  #   end
  #
  # @example Bypass serialization
  #   store.store('key', 'value', :raw => true)
  #   store['key'] => Error
  #   store.load('key', :raw => true) => 'value'
  #
  #   store['key'] = 'value'
  #   store.load('key', :raw => true) => "\x04\bI\"\nvalue\x06:\x06ET"
  #
  # @api public
  class Transformer < Proxy
    class << self
      alias_method :original_new, :new

      # Constructor
      #
      # @param [Moneta store] adapter The underlying store
      # @param [Hash] options
      # @return [Transformer] new Moneta transformer
      # @option options [Array] :key List of key transformers in the order in which they should be applied
      # @option options [Array] :value List of value transformers in the order in which they should be applied
      # @option options [String] :prefix Prefix string for key namespacing (Used by the :prefix key transformer)
      # @option options [String] :secret HMAC secret to verify values (Used by the :hmac value transformer)
      # @option options [Integer] :maxlen Maximum key length (Used by the :truncate key transformer)
      # @option options [Boolean] :quiet Disable error message
      def new(adapter, options = {})
        keys = [options[:key]].flatten.compact
        values = [options[:value]].flatten.compact
        raise ArgumentError, 'Option :key or :value is required' if keys.empty? && values.empty?
        options[:prefix] ||= '' if keys.include?(:prefix)
        name = class_name(options[:quiet] ? 'Quiet' : '', keys, values)
        const_set(name, compile(options, keys, values)) unless const_defined?(name)
        const_get(name).original_new(adapter, options)
      end

      private

      def compile(options, keys, values)
        @key_validator ||= compile_validator(KEY_TRANSFORMER)
        @value_validator ||= compile_validator(VALUE_TRANSFORMER)

        raise ArgumentError, 'Invalid key transformer chain' if @key_validator !~ keys.map(&:inspect).join
        raise ArgumentError, 'Invalid value transformer chain' if @value_validator !~ values.map(&:inspect).join

        key = compile_transformer(keys, 'key')

        klass = Class.new(self)
        klass.class_eval <<-end_eval, __FILE__, __LINE__
          def initialize(adapter, options = {})
            super
            #{compile_initializer('key', keys)}
            #{compile_initializer('value', values)}
          end
          def key?(key, options = {})
            @adapter.key?(#{key}, options)
          end
          def increment(key, amount = 1, options = {})
            @adapter.increment(#{key}, amount, options)
          end
        end_eval

        if values.empty?
          klass.class_eval <<-end_eval, __FILE__, __LINE__
            def load(key, options = {})
              options.delete(:raw)
              @adapter.load(#{key}, options)
            end
            def store(key, value, options = {})
              options.delete(:raw)
              @adapter.store(#{key}, value, options)
            end
            def delete(key, options = {})
              options.delete(:raw)
              @adapter.delete(#{key}, options)
            end
          end_eval
        else
          dump = compile_transformer(values, 'value')
          load = compile_transformer(values.reverse, 'value', 1)

          klass.class_eval <<-end_eval, __FILE__, __LINE__
            def load(key, options = {})
              raw = options.delete(:raw)
              value = @adapter.load(#{key}, options)
              begin
                return #{load} if value && !raw
              rescue Exception => ex
                #{options[:quiet] ? '' : 'puts "Tried to load invalid value: #{ex.message}"'}
              end
              value
            end
            def store(key, value, options = {})
              raw = options.delete(:raw)
              @adapter.store(#{key}, raw ? value : #{dump}, options)
              value
            end
            def delete(key, options = {})
              raw = options.delete(:raw)
              value = @adapter.delete(#{key}, options)
              begin
                return #{load} if value && !raw
              rescue Exception => ex
                #{options[:quiet] ? '' : 'puts "Tried to delete invalid value: #{ex.message}"'}
              end
              value
            end
          end_eval
        end
        klass
      end

      # Compile option initializer
      def compile_initializer(type, transformers)
        transformers.map do |name|
          t = TRANSFORMER[name]
          (t[1].to_s + t[2].to_s).scan(/@\w+/).uniq.map do |opt|
            "raise ArgumentError, \"Option #{opt[1..-1]} is required for #{name} #{type} transformer\" unless #{opt} = options[:#{opt[1..-1]}]\n"
          end
        end.join("\n")
      end

      # Compile transformer validator regular expression
      def compile_validator(s)
        Regexp.new(s.gsub(/\w+/) do
                     '(' + TRANSFORMER.select {|k,v| v.first.to_s == $& }.map {|v| ":#{v.first}" }.join('|') + ')'
                   end.gsub(/\s+/, '').sub(/\A/, '\A').sub(/\Z/, '\Z'))
      end

      # Returned compiled transformer code string
      def compile_transformer(transformer, var, i = 2)
        transformer.inject(var) do |value, name|
          raise ArgumentError, "Unknown transformer #{name}" unless t = TRANSFORMER[name]
          require t[3] if t[3]
          code = t[i]
          if t[0] == :serialize && var == 'key'
            "(tmp = #{value}; String === tmp ? tmp : #{code % 'tmp'})"
          else
            code % value
          end
        end
      end

      def class_name(prefix, keys, values)
        prefix << (keys.empty? ? '' : keys.map(&:to_s).map(&:capitalize).join << 'Key') <<
          (values.empty? ? '' : values.map(&:to_s).map(&:capitalize).join << 'Value')
      end
    end
  end
end

require 'moneta/transformer/helper'
require 'moneta/transformer/config'
