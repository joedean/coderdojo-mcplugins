require "fileutils"
require "tempfile"
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

      def success(message)
        puts "#{message} is installed correctly!"
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

  class CheckEnvironment
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
      minimum_java_version = 6
      version = Java::JavaLang::System.get_property "java.version"
      major = version.split(".")[1].to_i

      if major < minimum_java_version
        CoderDojo::Util.error "Your current version of Java is: #{version}\n  Please upgrade to Java 1.#{minimum_java_version} or higher."
      end
    end

    def check_minecraft
      CoderDojo::Util.error "Could not find Minecraft at:\n  #{CoderDojo::Paths.minecraft_dir}\nPlease install Minecraft." unless File.exists? CoderDojo::Paths.minecraft_dir
      CoderDojo::Util.success "Minecraft"
    end

    def check_jdk
      CoderDojo::Util.error "Need to install javac version #{java_version} or make sure javac is on your PATH" unless CoderDojo::Util.which "javac"
      CoderDojo::Util.error "Your java version and javac version do not match. [java = #{java_version} and javac = #{javac_version}]" unless java_versions_match?
      CoderDojo::Util.success "JDK version #{javac_version}"
    end

    def check_bukkit
      craftbukkit_path = File.join CoderDojo::Paths.server_dir, 'craftbukkit.jar'

      # TODO: check file size of craftbukkit.jar
      unless File.exists? craftbukkit_path
        puts "Downloading craftbukkit.jar.  Please wait..."
        CoderDojo::Util.download "http://dl.bukkit.org/latest-rb/craftbukkit.jar", craftbukkit_path
      end

      CoderDojo::Util.success "Minecraft server Craftbukkit"
    end

    def check_sublime
      path = CoderDojo::Util.which "sublime_text"
      path = CoderDojo::Util.which "Sublime Text 2" if !path && CoderDojo::Util.mac?
      CoderDojo::Util.error "Install Sublime Text 2 and make sure it's in your PATH" unless path
      CoderDojo::Util.success "Sublime Text"
    end

    def check_forge
      forge = "forge-#{CoderDojo.forge_version}"
      forge_path = File.join CoderDojo::Paths.minecraft_dir, "versions", forge

      unless File.exists? forge_path
        installer_path = File.join CoderDojo::Paths.temp_dir, "forge-installer.jar"
        CoderDojo::Util.save_file! "forge-installer.jar", installer_path
        puts "Make sure minecraft has run at least once in 1.6.4 mode"
        puts "When the simple forge installer dialog comes up select 'Install client' and click 'Ok'"
        %x[java -jar '#{installer_path}']
      end

      coderdojo_path = CoderDojo::Util.mkdir File.join(CoderDojo::Paths.minecraft_dir, "versions", "coderdojo")
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
                version_value = CoderDojo.forge_version.sub "-", "-Forge"
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

      CoderDojo::Util.success "Forge"
    end

    def check_computer_craft
      mods_dir = File.join CoderDojo::Paths.minecraft_dir, "mods"
      mod_path = File.join mods_dir, "ComputerCraft.zip"

      unless File.exists? mod_path
        CoderDojo::Util.save_file! "ComputerCraft.zip", mod_path
      end

      CoderDojo::Util.success "Computer Craft"
    end

    def generate_key
      puts "-------------------------"
      decoded_key = "Version #{CoderDojo.version} - #{CoderDojo::Config[:name]}"
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
      %x[java -version 2>&1][/(?:\d+(?:\.|_)?)+/]
    end

    def javac_version
      %x[javac -version 2>&1][/(?:\d+(?:\.|_)?)+/]
    end

    def session_requires_java_development?
      false
    end
  end
end

CoderDojo::CheckEnvironment.new.run
