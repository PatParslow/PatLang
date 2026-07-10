# frozen_string_literal: true

# PatLang Standard Library - IO Module
# Provides input/output functions

module Patlang
  module Stdlib
    module IO
      FUNCTIONS = {}
      
      def self.register(name, arity, &block)
        FUNCTIONS[name] = { arity: arity, impl: block }
      end
      
      def self.get(name)
        FUNCTIONS[name]
      end
      
      def self.all
        FUNCTIONS.keys
      end
      
      def self.init!
        # Print to stdout
        register("print", 1) do |args, env|
          $stdout.print(args[0].to_s)
          args[0]
        end
        
        register("println", 1) do |args, env|
          $stdout.puts(args[0].to_s)
          args[0]
        end
        
        # Print multiple values
        register("print_all", -1) do |args, env|
          args.each { |a| $stdout.print(a.to_s) }
          args.last
        end
        
        register("println_all", -1) do |args, env|
          args.each { |a| $stdout.puts(a.to_s) }
          args.last
        end
        
        # Format string
        register("format", -1) do |args, env|
          format_str = args[0].to_s
          format_args = args[1..]
          format_str % format_args
        end
        
        register("sprintf", -1) do |args, env|
          format_str = args[0].to_s
          format_args = args[1..]
          format_str % format_args
        end
        
        # Read from stdin
        register("read_line", 0) do |args, env|
          $stdin.gets&.chomp
        end
        
        register("read_all", 0) do |args, env|
          $stdin.read
        end
        
        # File operations
        register("file_read", 1) do |args, env|
          path = args[0].to_s
          File.read(path)
        end
        
        register("file_write", 2) do |args, env|
          path = args[0].to_s
          content = args[1].to_s
          File.write(path, content)
          true
        end
        
        register("file_append", 2) do |args, env|
          path = args[0].to_s
          content = args[1].to_s
          File.open(path, 'a') { |f| f.write(content) }
          true
        end
        
        register("file_exists?", 1) do |args, env|
          File.exist?(args[0].to_s)
        end
        
        register("file_delete", 1) do |args, env|
          File.delete(args[0].to_s)
          true
        end
        
        register("file_read_lines", 1) do |args, env|
          path = args[0].to_s
          File.readlines(path, chomp: true)
        end
        
        register("file_write_lines", 2) do |args, env|
          path = args[0].to_s
          lines = args[1]
          raise TypeError, "Second argument must be a list" unless lines.is_a?(Array)
          File.write(path, lines.join("\n"))
          true
        end
        
        register("dir_exists?", 1) do |args, env|
          Dir.exist?(args[0].to_s)
        end
        
        register("dir_create", 1) do |args, env|
          Dir.mkdir(args[0].to_s)
          true
        end
        
        register("dir_list", 1) do |args, env|
          path = args[0].to_s
          Dir.entries(path) - ['.', '..']
        end
        
        # JSON
        register("json_parse", 1) do |args, env|
          require 'json'
          JSON.parse(args[0].to_s)
        end
        
        register("json_stringify", 1) do |args, env|
          require 'json'
          JSON.generate(args[0])
        end
        
        # YAML
        register("yaml_parse", 1) do |args, env|
          require 'yaml'
          YAML.safe_load(args[0].to_s)
        end
        
        register("yaml_stringify", 1) do |args, env|
          require 'yaml'
          args[0].to_yaml
        end
      end
      
      init!
    end
  end
end