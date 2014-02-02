require 'fileutils'
require 'open-uri'
require 'zlib'

class CheckEnvironment
  VERSION="0.1"
  FILE_SEPARATOR = java.lang.System.getProperty "file.separator"
  CODERDOJO_DIR = "~#{FILE_SEPARATOR}.coderdojo"

  def run
    prompt_for_user_name
    check_java
    check_bukkit
    check_sublime
    generate_key
  end

  private
  def prompt_for_user_name
    @name = prompt_user_name "Hello! Please enter your Minecraft user name: "
    if @name.empty?
      @name = prompt_user_name "Common you need to do better than that! Try entering your Minecraft user name again. "
    end
    raise "Failed to provide a valid Minecraft user name.  Please try again!" if @name.empty?
    puts "Awesome!  Thanks #{@name}!  Please be patience while I inspect your environment..."
  end

  def prompt_user_name request_msg
    print request_msg
    user_input = gets
    user_input.strip
  end

  def check_java
    raise "Need to install javac version #{java_version} or make sure javac is on your PATH" unless which "javac"
    raise "Your java version and javac version do not match. [java = #{java_version} and javac = #{javac_version}]" unless java_versions_match?
    success "JDK version #{javac_version}"
  end

  def java_versions_match?
    java_version == javac_version
  end

  def java_version
    %x[java -version 2>&1 | head -1 | awk -F '"' '{print $2}'].strip
  end

  def javac_version
    %x[javac -version 2>&1 | awk -F ' ' '{print $2}'].strip
  end

  def check_bukkit
    mkdir "server"
    # check file size of craftbukkit.jar
    unless File.exists? "server#{FILE_SEPARATOR}craftbukkit.jar"
      puts "Downloading craftbukkit.jar.  Please wait..."
      download "http://dl.bukkit.org/latest-rb/craftbukkit.jar", "server#{FILE_SEPARATOR}craftbukkit.jar"
    end
    success "Minecraft server Craftbukkit"
  end

  def download url, location
    File.open(location, "wb") do |saved_file|
      open(url, "rb") do |read_file|
        saved_file.write(read_file.read)
      end
    end
  end

  def mkdir dir
    FileUtils.mkdir dir unless File.directory? dir
  end

  def check_sublime
    raise "Install sublime_text and make sure it's in your PATH" unless which "sublime_text"
    success "Sublime Text"
  end

  def generate_key
    puts "-------------------------"
    value_to_encrypt = "Version #{VERSION} - #{@name}"
    puts value_to_encrypt
    encrypted_value = deflate(value_to_encrypt)
    puts encrypted_value
    puts "-------------------------"
  end

  def deflate(string, level=Zlib::BEST_SPEED)
    z = Zlib::Deflate.new(level)
    dst = z.deflate(string, Zlib::FINISH)
    z.close
    dst
  end

  def success message
    puts "#{message} is installed correctly!"
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
end

CheckEnvironment.new.run
