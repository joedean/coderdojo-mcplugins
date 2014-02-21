require "fileutils"
require "tempfile"
require "open-uri"
require "yaml"

module CoderDojo
  VERSION = Java::ComCoderdojoMcplugins::Main.version
  FORGE_VERSION = Java::ComCoderdojoMcplugins::Main.forge_version
  USER_HOME = Java::JavaLang::System.get_property "user.home"
  HOME = File.join USER_HOME, "coderdojo"
  SERVER = File.join HOME, "server"
  TEMP = File.join HOME, "tmp"

  class << self
    def home_dir
      CoderDojo::Util.mkdir CoderDojo::HOME
    end

    def server_dir
      CoderDojo::Util.mkdir CoderDojo::SERVER
    end

    def temp_dir
      CoderDojo::Util.mkdir CoderDojo::TEMP
    end
  end

  class Util
    class << self
      def error(message, problem = true)
        if problem
          STDERR.puts "There is a problem with your environment:\n"
        end

        STDERR.puts message
        Java::JavaLang::System.exit 1
      end

      def mkdir(dir)
        return dir if File.exists?(dir) && File.directory?(dir)
        FileUtils.mkdir dir
        dir
      end

      def save_file!(resource, target)
        Java::ComCoderdojoMcplugins::Main.save_file resource, target
      end
    end
  end

  class Config
    PATH = File.join CoderDojo.home_dir, "config.yml"

    class << self
      def [](key)
        load[key]
      end

      def []=(key, value)
        load[key] = value
        save!
      end

      private
      def load
        return @config if @config

        if File.exists? CoderDojo::Config::PATH
          @config = YAML.load File.read(CoderDojo::Config::PATH)
        else
          @config = {}
          save!
        end

        @config
      end

      def save!
        File.write CoderDojo::Config::PATH, YAML.dump(@config)
      end
    end
  end

  class CheckEnvironment
    APP_ROOT = File.join File.dirname(__FILE__), '..'
    PLATFORM = RbConfig::CONFIG["host_os"]
    MINIMUM_JAVA_VERSION = 6

    def run
      prompt_for_user_name
      check_java
      check_minecraft

      if session_requires_java_development?
        check_jdk
        check_bukkit
        check_sublime
      end

      check_forge
      check_computer_craft
      generate_key
    end

    private
    def prompt_for_user_name
      return if CoderDojo::Config[:name]
      name = prompt_user_name "Hello! Please enter your Minecraft user name: "

      if name.empty?
        name = prompt_user_name "Common you need to do better than that!\nTry entering your Minecraft user name again: "
      end

      CoderDojo::Util.error "Failed to provide a valid Minecraft user name.\nPlease try again!" if name.empty?
      CoderDojo::Config[:name] = name
      puts "Please be patient while I inspect your environment..."
    end

    def check_java
      version = Java::JavaLang::System.get_property "java.version"
      major = version.split(".")[1].to_i

      if major < MINIMUM_JAVA_VERSION
        CoderDojo::Util.error "Your current version of Java is: #{version}
  Please upgrade to Java 1.#{MINIMUM_JAVA_VERSION} or higher."
      end
    end

    def check_minecraft
      CoderDojo::Util.error "Could not find Minecraft at:\n  #{minecraft_path}\nPlease install Minecraft." unless File.exists? minecraft_path
    end

    def check_jdk
      raise "Need to install javac version #{java_version} or make sure javac is on your PATH" unless which "javac"
      raise "Your java version and javac version do not match. [java = #{java_version} and javac = #{javac_version}]" unless java_versions_match?
      success "JDK version #{javac_version}"
    end

    def check_bukkit
      craftbukkit_path = File.join CoderDojo.server_dir, 'craftbukkit.jar'

      #TODO: check file size of craftbukkit.jar
      unless File.exists? craftbukkit_path
        puts "Downloading craftbukkit.jar.  Please wait..."
        download "http://dl.bukkit.org/latest-rb/craftbukkit.jar", craftbukkit_path
      end
      success "Minecraft server Craftbukkit"
    end

    def check_sublime
      path = which "sublime_text"
      path = which "Sublime Text 2" if mac?
      raise "Install Sublime Text 2 and make sure it's in your PATH" unless path
      success "Sublime Text"
    end

    def check_forge
      forge = "forge-#{CoderDojo::FORGE_VERSION}"
      forge_path = File.join minecraft_path, "versions", forge

      unless File.exists? forge_path
        installer_path = File.join CoderDojo.temp_dir, "forge-installer.jar"
        CoderDojo::Util.save_file! "forge-installer.jar", installer_path
        puts "Make sure minecraft has run at least once in 1.6.4 mode"
        puts "When the simple forge installer dialog comes up select 'Install client' and click 'Ok'"
        %x[java -jar '#{installer_path}']
      end

      coderdojo_path = CoderDojo::Util.mkdir File.join(minecraft_path, "versions", "coderdojo")
      forge_json = File.join forge_path, "#{forge}.json"
      forge_jar = File.join forge_path, "#{forge}.jar"
      json_path = File.join coderdojo_path, "coderdojo.json"
      jar_path = File.join coderdojo_path, "coderdojo.jar"

      CoderDojo::Util.error "Could not find Forge jar.\nIs Forge installed properly?" unless File.exists? forge_jar
      CoderDojo::Util.error "Could not find Forge json.\nIs Forge installed properly?" unless File.exists? forge_json

      if !File.exists?(json_path) || !File.exists?(jar_path)
        FileUtils.cp forge_json, json_path
        FileUtils.cp forge_jar, jar_path
        temp_file = Tempfile.new("coderdojo.json")

        begin
          File.open(json_path, "r") do |file|
            file.each_line do |line|
              if /"id": ".*",/ =~ line
                version_value = CoderDojo::FORGE_VERSION.sub "-", "-Forge"
                temp_file.puts line.gsub(version_value, "coderdojo")
              else
                temp_file.puts line
              end
            end
          end

          temp_file.rewind
          FileUtils.mv temp_file.path, json_path
        ensure
          temp_file.close
          temp_file.unlink
        end
      end
    end

    def check_computer_craft
      mods_dir = File.join minecraft_path, 'mods'
      unless File.exists? File.join(mods_dir, 'ComputerCraft1.58.zip')
        FileUtils.cp(File.join(APP_ROOT, 'minecraft', 'ComputerCraft1.58.zip'),
                     File.join(mods_dir, 'ComputerCraft1.58.zip'))
      end
    end

    def generate_key
      puts "-------------------------"
      decoded_key = "Version #{CoderDojo::VERSION} - #{CoderDojo::Config[:name]}"
      puts decoded_key
      encoded_key = [decoded_key].pack "u"
      puts encoded_key
      puts "-------------------------"
    end

    ### Utility Methods ###
    # Manages user input
    def prompt_user_name request_msg
      print request_msg
      user_input = gets
      CoderDojo::Util.error "Well, please try again later!", false unless user_input
      user_input.strip
    end

    # Java version helper methods
    def java_versions_match?
      java_version == javac_version
    end

    def java_version
      %x[java -version 2>&1 | head -1 | awk -F '"' '{print $2}'].strip
    end

    def javac_version
      %x[javac -version 2>&1 | awk -F ' ' '{print $2}'].strip
    end

    # Delivers success message when environment check completes successfully
    def success message
      puts "#{message} is installed correctly!"
    end

    # Download url to a specified location
    def download url, location
      File.open(location, "wb") do |saved_file|
        open(url, "rb") do |read_file|
          saved_file.write(read_file.read)
        end
      end
    end

    # Cross-platform way of finding an executable in the $PATH
    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable? exe
        }
      end
      return nil
    end

    def minecraft_path
      if linux?
        File.join USER_HOME, ".minecraft"
      elsif mac?
        File.join USER_HOME, "Library", "Application Support", "minecraft"
      elsif windows?
        File.join USER_HOME, "Application Data", ".minecraft"
      else
        CoderDojo::Util.error "Cannot determine your platform from '#{PLATFORM}'"
      end
    end

    def linux?
      PLATFORM == "linux"
    end

    def mac?
      PLATFORM == "darwin"
    end

    def windows?
      PLATFORM == "mswin32"
    end

    def session_requires_java_development?
      false
    end
  end
end

CoderDojo::CheckEnvironment.new.run
