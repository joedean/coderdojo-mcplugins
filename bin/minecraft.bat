@echo off
path %PATH%;%JAVA_HOME%\bin\
for /f tokens^=2-5^ delims^=.-_^" %%j in ('java -fullversion 2^>^&1') do set "jver=%%j.%%k.%%l%%m"
echo %jver%

if "%jver%" == "" (
  echo Please install Java or configure PATH to include Java.
  goto :eof
)

if %jver% lss 1.6 (
   echo Your current version of Java is %jver%. Please upgrade to Java 1.6 or higher.
   goto :eof
)

cd %HOMEPATH%
if not exist coderdojo mkdir coderdojo
cd coderdojo

if not exist %HOMEDRIVE%\PROGRA~1\GnuWin32\bin\wget.exe (
   echo The file wget.exe was not found. Make sure you download it from http://downloads.sourceforge.net/gnuwin32/wget-1.11.4-1-setup.exe and install!
) else (
  PATH=%PATH%;%HOMEDRIVE%\PROGRA~1\GnuWin32\bin
)

if not exist lib\jruby-complete.jar (
  if not exist 7z920.exe (
    wget http://downloads.sourceforge.net/sevenzip/7z920.exe
    7z920.exe
  )
  wget --no-check-certificate https://github.com/joedean/coderdojo-mcplugins/archive/master.zip
  move master master.zip
  %HOMEDRIVE%\progra~1\7-zip\7z.exe x master.zip
  cd coderdojo-mcplugins-master
  for %%i in (*) do move "%%i" ..
  for /d %%i in (*) do move "%%i" ..
  cd ..
  rmdir coderdojo-mcplugins-master
)

java -Xmx500m -Xss1024k -jar lib\jruby-complete.jar lib\check_environment.rb
