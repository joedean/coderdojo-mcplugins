require 'tempfile'
require 'fileutils'
require 'open-uri'

module CoderDojo
  class CheckEnvironment
    VERSION = Java::ComCoderdojoMcplugins::Main.version
    USER_HOME = Java::JavaLang::System.get_property "user.home"
    CODERDOJO_HOME = File.join USER_HOME, "coderdojo"
    SERVER_PATH = File.join CODERDOJO_HOME, "server"
    APP_ROOT = File.join File.dirname(__FILE__), '..'
    PLATFORM = RbConfig::CONFIG["host_os"]
    MINIMUM_JAVA_VERSION = 6

    def run
      prep!
      prompt_for_user_name
      check_java

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
    def prep!
      mkdir CODERDOJO_HOME
      mkdir SERVER_PATH
    end

    def prompt_for_user_name
      @name = prompt_user_name "Hello! Please enter your Minecraft user name: "
      if @name.empty?
        @name = prompt_user_name "Common you need to do better than that! Try entering your Minecraft user name again. "
      end
      raise "Failed to provide a valid Minecraft user name.  Please try again!" if @name.empty?
      puts "Please be patience while I inspect your environment..."
    end

    def check_java
      version = Java::JavaLang::System.get_property "java.version"
      major = version.split(".")[1].to_i

      if major < MINIMUM_JAVA_VERSION
        error "Your current version of Java is: #{version}
  Please upgrade to Java 1.#{MINIMUM_JAVA_VERSION} or higher."
      end
    end

    def check_jdk
      raise "Need to install javac version #{java_version} or make sure javac is on your PATH" unless which "javac"
      raise "Your java version and javac version do not match. [java = #{java_version} and javac = #{javac_version}]" unless java_versions_match?
      success "JDK version #{javac_version}"
    end

    def check_bukkit
      craftbukkit_path = File.join SERVER_PATH, 'craftbukkit.jar'

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
      forge = 'forge-1.6.4-9.11.1.965'
      coderdojo_path = File.join minecraft_path, 'versions', 'coderdojo'
      forge_path = File.join minecraft_path, 'versions', forge
      forge_installer = File.join APP_ROOT, 'minecraft', "#{forge}-installer.jar"
      json_path = File.join coderdojo_path, 'coderdojo.json'

      puts "Make sure minecraft has run at least once in 1.6.4 mode"
      puts "When the simple forge installer dialog comes up select 'Install client' and click 'Ok'"
      %x[java -jar #{forge_installer}]
      mkdir coderdojo_path unless Dir.exists? coderdojo_path
      unless File.exists? File.join(coderdojo_path, 'coderdojo.json')
        FileUtils.cp File.join(forge_path, "#{forge}.jar"), File.join(coderdojo_path, 'coderdojo.jar')
        FileUtils.cp File.join(forge_path, "#{forge}.json"), json_path
      end

      temp_file = Tempfile.new('coderdojo.json')
      begin
        File.open(json_path, 'r') do |file|
          file.each_line do |line|
            if (!!(/"id": ".*",/ =~ line))
              temp_file.puts line.gsub(/1\.6\.4-Forge9\.11\.1\.965/, 'coderdojo')
            else
              temp_file.puts line
            end
          end
        end
        temp_file.rewind
        FileUtils.mv(temp_file.path, json_path)
      ensure
        temp_file.close
        temp_file.unlink
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
      decoded_key = "Version #{VERSION} - #{@name}"
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

    def error message
      STDERR.puts "There is a problem with your environment:\n\n#{message}"
      exit false
    end

    # Download url to a specified location
    def download url, location
      File.open(location, "wb") do |saved_file|
        open(url, "rb") do |read_file|
          saved_file.write(read_file.read)
        end
      end
    end

    # Helper method for making a directory on filesystem
    def mkdir dir
      FileUtils.mkdir dir unless File.directory? dir
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
        error "Cannot determine your platform from '#{PLATFORM}'"
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
