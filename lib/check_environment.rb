require "fileutils"

module CoderDojo
  module Checks
    class UserName
      include CoderDojo::Check
      name "Minecraft User Name"

      def done?
        CoderDojo::Config[:name]
      end

      def prepare!
        name = prompt_user_name "Please enter your Minecraft user name: "

        if name.empty?
          name = prompt_user_name "C'mon you need to do better than that!\nTry entering your Minecraft user name again: "
        end

        error! "Failed to provide a valid Minecraft user name.\nPlease try again!" if name.empty?
        CoderDojo::Config[:name] = name
      end

      def prompt_user_name(request_msg)
        print request_msg
        user_input = gets
        CoderDojo::Util.error "Well, please try again later!", false unless user_input
        user_input.strip
      end
    end

    class JavaVersion
      include CoderDojo::Check
      name "Java Version"

      def done?
        minimum_java_version = 6
        version = Java::JavaLang::System.get_property "java.version"
        major = version.split(".")[1].to_i

        if major < minimum_java_version
          error! "Your current version of Java is: #{version}\nPlease upgrade to Java 1.#{minimum_java_version} or higher."
        end

        true
      end
    end

    class Minecraft
      include CoderDojo::Check
      name "Minecraft"

      def done?
        unless File.exists? CoderDojo::Paths.minecraft_dir
          error! "Could not find Minecraft at:\n  #{CoderDojo::Paths.minecraft_dir}\nPlease install Minecraft."
        end

        true
      end
    end

    class JDKVersion
      include CoderDojo::Check
      name "JDK Version"

      def done?
        error! "Need to install javac version #{java_version} or make sure javac is on your PATH" unless CoderDojo::Util.which "javac"
        error! "Your java version and javac version do not match. [java = #{java_version} and javac = #{javac_version}]" unless java_versions_match?
        true
      end

      def java_versions_match?
        java_version == javac_version
      end

      def java_version
        %x[java -version 2>&1][/(?:\d+(?:\.|_)?)+/]
      end

      def javac_version
        %x[javac -version 2>&1][/(?:\d+(?:\.|_)?)+/]
      end
    end

    class Bukkit
      include CoderDojo::Check
      name "Minecraft Server Craftbukkit"
      verb "Installing"

      def done?
        File.exists? craftbukkit_path
      end

      def prepare!
        # TODO: check file size of craftbukkit.jar
        puts "Downloading craftbukkit.jar.  Please wait..."
        CoderDojo::Util.download "http://dl.bukkit.org/latest-rb/craftbukkit.jar", craftbukkit_path
      end

      def craftbukkit_path
        File.join CoderDojo::Paths.server_dir, "craftbukkit.jar"
      end
    end

    class Sublime
      include CoderDojo::Check
      name "Sublime Text 2"

      def done?
        error! "Install Sublime Text 2 and make sure it's in your PATH" unless sublime_path
        true
      end

      def sublime_path
        path = CoderDojo::Util.which "sublime_text"
        path = CoderDojo::Util.which "Sublime Text 2" if !path && CoderDojo::Util.mac?
        path
      end
    end

    class Forge
      include CoderDojo::Check
      name "Forge"
      verb "Installing"

      def done?
        File.exists?(forge_jar_path) && File.exists?(coderdojo_json_path) && File.exists?(coderdojo_jar_path)
      end

      def prepare!
        unless File.exists? forge_jar_path
          installer_path = File.join CoderDojo::Paths.temp_dir, "forge-installer.jar"
          CoderDojo::Util.save_file! "forge-installer.jar", installer_path
          puts "Make sure minecraft has run at least once in 1.6.4 mode"
          puts "When the simple forge installer dialog comes up select 'Install client' and click 'Ok'"
          %x[java -jar '#{installer_path}']
        end

        CoderDojo::Util.mkdir coderdojo_path
        error! "Could not find Forge jar at: #{forge_jar_path}\nIs Forge installed properly?" unless File.exists? forge_jar_path
        error! "Could not find Forge json at: #{forge_json_path}\nIs Forge installed properly?" unless File.exists? forge_json_path

        if !File.exists?(coderdojo_json_path) || !File.exists?(coderdojo_jar_path)
          FileUtils.cp forge_jar_path, coderdojo_jar_path

          File.open(forge_json_path, "r") do |file|
            File.open(coderdojo_json_path, "w") do |output_file|
              file.each_line do |line|
                if /"id": ".*",/ =~ line
                  output_file.puts line.gsub(forge_version_name, "coderdojo")
                else
                  output_file.puts line
                end
              end
            end
          end
        end
      end

      def forge_version_name
        CoderDojo.forge_version.sub "-", "-Forge"
      end

      def forge_path
        File.join CoderDojo::Paths.minecraft_dir, "versions", forge_version_name
      end

      def coderdojo_path
        File.join CoderDojo::Paths.minecraft_dir, "versions", "coderdojo"
      end

      def forge_json_path
        File.join forge_path, "#{forge_version_name}.json"
      end

      def forge_jar_path
        File.join forge_path, "#{forge_version_name}.jar"
      end

      def coderdojo_json_path
        File.join coderdojo_path, "coderdojo.json"
      end

      def coderdojo_jar_path
        File.join coderdojo_path, "coderdojo.jar"
      end
    end

    class ComputerCraft
      include CoderDojo::Check
      name "ComputerCraft"
      verb "Installing"

      def done?
        File.exists? computer_craft_path
      end

      def prepare!
        CoderDojo::Util.mkdir mods_dir
        CoderDojo::Util.save_file! "ComputerCraft.zip", computer_craft_path
      end

      def mods_dir
        File.join CoderDojo::Paths.minecraft_dir, "mods"
      end

      def computer_craft_path
        File.join mods_dir, "ComputerCraft.zip"
      end
    end
  end

  class CheckEnvironment
    def run
      puts "Please be patient while I inspect your environment..."
      CoderDojo::Checks::UserName.check!
      CoderDojo::Checks::JavaVersion.check!
      CoderDojo::Checks::Minecraft.check!

      if session_requires_java_development?
        CoderDojo::Checks::JDKVersion.check!
        CoderDojo::Checks::Bukkit.check!
        CoderDojo::Checks::Sublime.check!
      end

      CoderDojo::Checks::Forge.check!
      CoderDojo::Checks::ComputerCraft.check!
      generate_key
    end

    private
    def generate_key
      puts "-------------------------"
      decoded_key = "Version #{CoderDojo.version} - #{CoderDojo::Config[:name]}"
      puts decoded_key
      encoded_key = BubbleBabble.md5 decoded_key
      puts encoded_key
      puts "-------------------------"
    end

    def session_requires_java_development?
      false
    end
  end
end

CoderDojo::CheckEnvironment.new.run
