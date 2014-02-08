#!/bin/sh
if [ "$1" != "check_env" ]; then
  echo "Usage: $0 check_env"
  exit 1
fi

SCRIPT='lib/check_environment.rb'
ACCEPTABLE_JAVA_VERSION=6
JAVA_VERSION=`java -version 2>&1 | head -1 | awk -F '"' '{print $2}'`
JVM_HEAP_STACK_SETTINGS='-Xmx500m -Xss1024k'

if [ ${JAVA_VERSION} = "" ]; then
  echo Please install Java or configure PATH to include Java.
  exit 1
fi
JAVA_MAJOR_VERSION=`echo ${JAVA_VERSION} | cut -d '.' -f 2`

if [ ${JAVA_MAJOR_VERSION} -lt ${ACCEPTABLE_JAVA_VERSION} ]; then
  echo Your current version of Java is ${JAVA_VERSION}. Please upgrade to Java 1.6 or higher.
  exit 1
fi

if [ `which curl` = "" ]; then
  echo Please install curl from http://curl.haxx.se/download.html and try again.
  exit 1
fi

if [ ! -d ~/coderdojo ]; then
  mkdir ~/coderdojo
fi
cd ~/coderdojo
if [ ! -f ~/coderdojo/lib/jruby-complete.jar ]; then
  curl -L -o coderdojo-mcplugins.zip -k https://github.com/joedean/coderdojo-mcplugins/archive/master.zip
  unzip coderdojo-mcplugins.zip
  mv ~/coderdojo/coderdojo-mcplugins-master/* ~/coderdojo/
  rmdir ~/coderdojo/coderdojo-mcplugins-master
  rm coderdojo-mcplugins.zip
fi

java ${JVM_HEAP_STACK_SETTINGS} -jar lib/jruby-complete.jar ${SCRIPT}
