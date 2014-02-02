@echo off
PATH %PATH%;%JAVA_HOME%\bin\
for /f tokens^=2-5^ delims^=.-_^" %%j in ('java -fullversion 2^>^&1') do set "java_version=%%j.%%k.%%l%%m"
echo %java_version%
bitsadmin.exe /transfer "jruby-complete-download" https://github.com/joedean/coderdojo-mcplugins/archive/master.zip C:\DOCUME~1\Joe\master.zip