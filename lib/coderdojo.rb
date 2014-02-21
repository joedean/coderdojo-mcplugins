require "fileutils"
require "open-uri"
require "yaml"

module CoderDojo
  class << self
    def forge_version
      Java::ComCoderdojoMcplugins::Main.forge_version
    end

    def version
      Java::ComCoderdojoMcplugins::Main.version
    end
  end

  module Colorize
    FOREGROUND_COLORS = {
      :black  => "\e[30m",
      :red    => "\e[31m",
      :green  => "\e[32m",
      :yellow => "\e[33m",
      :blue   => "\e[34m",
      :purple => "\e[35m",
      :cyan   => "\e[36m",
      :white  => "\e[37m"
    }

    BACKGROUND_COLORS = {
      :black  => "\e[40m",
      :red    => "\e[41m",
      :green  => "\e[42m",
      :yellow => "\e[43m",
      :blue   => "\e[44m",
      :purple => "\e[45m",
      :cyan   => "\e[46m",
      :white  => "\e[47m"
    }

    COLOR_STYLES = {
      :bold => {
        true  => "\e[1m",
        false => "\e[22m"
      },

      :blink => {
        true  => "\e[5m",
        false => "\e[25m"
      },

      :reverse => {
        true  => "\e[7m",
        false => "\e[27m"
      },

      :reset => "\e[0m"
    }

    def colorize(options)
      fg = FOREGROUND_COLORS[options[:fg]]
      bg = BACKGROUND_COLORS[options[:bg]]
      reset = COLOR_STYLES[:reset]
      bold = COLOR_STYLES[:bold][!!options[:bold]] if options.include? :bold
      blink = COLOR_STYLES[:blink][!!options[:blink]] if options.include? :blink
      reverse = COLOR_STYLES[:reverse][!!options[:reverse]] if options.include? :reverse
      style = "#{bold}#{blink}#{reverse}"
      "#{fg}#{bg}#{style}#{self}#{reset}"
    end

    def black
      colorize :fg => :black
    end

    def red
      colorize :fg => :red
    end

    def green
      colorize :fg => :green
    end

    def yellow
      colorize :fg => :yellow
    end

    def blue
      colorize :fg => :blue
    end

    def purple
      colorize :fg => :purple
    end

    def cyan
      colorize :fg => :cyan
    end

    def white
      colorize :fg => :white
    end

    def bold
      colorize :bold => true
    end

    def blink
      colorize :blink => true
    end

    def reverse
      colorize :reverse => true
    end
  end

  module Check
    class Error < StandardError; end

    def check!
      @prepared = false
      print "Checking #{name}..."

      begin
        if done?
          puts " #{"success".green}"
          return
        end
      rescue CoderDojo::Check::Error => e
        puts " #{"FAILURE".red.bold}"
        CoderDojo::Util.error e.message.red, false
      end

      begin
        puts ""
        prepare!
        @prepared = true

        if done?
          puts "#{verb} #{name}: #{"success".green}"
          return
        else
          puts "#{verb} #{name}: #{"FAILURE".red.bold}"
          CoderDojo::Util.error "Error while #{verb.downcase} #{name}".red, false
        end
      rescue CoderDojo::Check::Error => e
        puts "#{verb} #{name}: #{"FAILURE".red.bold}"
        CoderDojo::Util.error e.message.red, false
      end
    end

    def prepare!
    end

    def done?
      @prepared
    end

    def error!(message)
      raise CoderDojo::Check::Error.new(message)
    end

    def name
      self.class.name
    end

    def verb
      self.class.verb
    end

    class << self
      def included(other)
        other.extend CoderDojo::Check::ClassMethods
      end
    end

    module ClassMethods
      def check!
        new.check!
      end

      def name(value = nil)
        if value.nil?
          @name
        else
          @name = value
        end
      end

      def verb(value = nil)
        if value.nil?
          @verb || "Checking"
        else
          @verb = value
        end
      end
    end
  end

  class Config
    class << self
      def [](key)
        load[key]
      end

      def []=(key, value)
        load[key] = value
        save!
      end

      private
      def path
        File.join CoderDojo::Paths.home_dir, "config.yml"
      end

      def load
        return @config if @config

        if File.exists? path
          @config = YAML.load File.read(path)
        else
          @config = {}
          save!
        end

        @config
      end

      def save!
        File.write path, YAML.dump(@config)
      end
    end
  end

  class Paths
    class << self
      def home_dir
        CoderDojo::Util.mkdir File.join(user_home_dir, "coderdojo")
      end

      def minecraft_dir
        if CoderDojo::Util.linux?
          File.join user_home_dir, ".minecraft"
        elsif CoderDojo::Util.mac?
          File.join user_home_dir, "Library", "Application Support", "minecraft"
        elsif CoderDojo::Util.windows?
          File.join user_home_dir, "Application Data", ".minecraft"
        else
          CoderDojo::Util.error "Cannot determine your platform from '#{CoderDojo::Util.platform}'"
        end
      end

      def server_dir
        CoderDojo::Util.mkdir File.join(home_dir, "server")
      end

      def temp_dir
        CoderDojo::Util.mkdir File.join(home_dir, "tmp")
      end

      def user_home_dir
        Java::JavaLang::System.get_property "user.home"
      end
    end
  end

  class Util
    class << self
      # Download url to a specified location
      def download(url, location)
        File.open(location, "wb") do |saved_file|
          open(url, "rb") do |read_file|
            saved_file.write(read_file.read)
          end
        end
      end

      def error(message, problem = true)
        if problem
          STDERR.puts "There is a problem with your environment:\n"
        end

        STDERR.puts message
        Java::JavaLang::System.exit 1
      end

      def linux?
        platform == "linux"
      end

      def mac?
        platform == "darwin"
      end

      def mkdir(dir)
        return dir if File.exists?(dir) && File.directory?(dir)
        FileUtils.mkdir dir
        dir
      end

      def platform
        RbConfig::CONFIG["host_os"]
      end

      def save_file!(resource, target)
        Java::ComCoderdojoMcplugins::Main.save_file resource, target
      end

      # Cross-platform way of finding an executable in the $PATH
      def which(cmd)
        exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]

        ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable? exe
          end
        end

        nil
      end

      def windows?
        platform == "mswin32"
      end
    end
  end
end

class String
  include CoderDojo::Colorize
end
