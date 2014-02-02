::get javaw.exe from the latest properly installed jre
for /f tokens^=2^ delims^=^" %%i in ('reg query HKEY_CLASSES_ROOT\jarfile\shell\open\command /ve') do set JAVAW_PATH=%%i

::if reg entry is not found, java is not installed
if "%JAVAW_PATH%"=="" goto YOUR_ERROR

::then strip "\javaw.exe" from the JAVAW_PATH obtained above
set JAVA_HOME=%JAVA_HOME:\javaw.exe=%