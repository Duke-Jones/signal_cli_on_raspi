
#!/bin/bash

function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) echo 1 ; return  ;;
            [Nn]*) echo 0 ; return  ;;
        esac
    done
}


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

newLineOne='export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-armhf"'
newLineTwo='PATH=${JAVA_HOME}:$PATH'

# required signal library type
arch=armv7-unknown-linux-gnueabihf
#arch=aarch64-unknown-linux-gnu

dest=/usr/local/signal
do_install=false

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root!" 1>&2
  echo
  exit 1
fi

# get Filename of the last version of signal-cli
signalfile=$(curl -s https://api.github.com/repos/AsamK/signal-cli/releases/latest | jq -r ".assets[] | select(.name | test(\"signal-cli-.*-Linux.tar.gz$\")) | .browser_download_url")
signalfilename=${signalfile##*/}
#echo $signalfile

# extract version string
versionsig=${signalfile##*/}
versionsig=${versionsig:11:-13}
#echo $versionsig
echo " -> new client version     : v$versionsig"

# now get the current installed version
currentversionfile=$(find /usr/local/bin/ -maxdepth 1 -name signal-cli)

if [ -z "$currentversionfile" ];
then
   echo " -> no current installation found -> installing now"
   do_install=true
else
   currentversionfile=$(echo "$currentversionfile" | xargs readlink -f)
   currentversion=$(echo "$currentversionfile" | cut -f5 --delimiter='/')
   currentversion=${currentversion:11}
   echo " -> current client version : v$currentversion"
   if [ "$versionsig" == "$currentversion" ];
   then
      echo " -> the versions are the same - install anyway ?"
      if [ "$(yes_or_no)" -eq 1  ];
      then
         do_install=true
      fi
   else
      echo " -> installing new version now"
      do_install=true
   fi
fi

# starting the installation
if [ "$do_install" == true ]; then

   # goto the destination directory
   cd $dest

   # delete old symbolic link
   if [ -f "/usr/local/bin/signal-cli" ];
   then
      rm /usr/local/bin/signal-cli
   fi

   # make a backup of the existing installation (or directory)
   existing=$(find /usr/local/signal/ -mindepth 1 -maxdepth 1 -name signal-cli-* | head -n 1)

   if [ "$existing" != "" ];
   then
      bckDir="backup_"$(date +"%Y%m%d_%H%M%S")
      echo " -> backup old signal directory into '$dest/$bckDir'"
      mkdir $bckDir
      cp -ra ./signal-cli-* ./$bckDir/
   fi

   # delete all files and folders which are not beginning with BACKUP
   find /usr/local/signal/ -mindepth 1 -maxdepth 1 -type f -delete
   find /usr/local/signal/ -mindepth 1 -maxdepth 1 -type d -not -iname "backup*" -exec rm -r "{}" \;

   echo " -> downloading new client"
   wget -q -P $dest $signalfile
   cat "$dest/$signalfilename" | tar -xzf - -i


   ###########################################################################
   # libsignal_jni.so
   ###########################################################################

   # getting version of included "libsignal-client*.jar"
   localib=$(ls ./signal-cli-$versionsig/lib/libsignal-client*.jar)
   # getting version
   versionlib=${localib##*/}
   versionlib=${versionlib:17:-4}
   echo " -> required version of the libsignal library ("$arch") : v"$versionlib

   # download the required library version
   libfile="https://github.com/exquo/signal-libs-build/releases/download/libsignal_v"$versionlib"/libsignal_jni.so-v"$versionlib"-"$arch".tar.gz"
   libfilename=${libfile##*/}
   wget -q -P $dest $libfile
   cat "$dest/$libfilename" | tar -xzf - -i

   echo " -> patching 'libsignal-client-$versionsig.jar' with customised libsignal library"
   zip -ujq $dest/signal-cli-$versionsig/lib/libsignal-client-$versionlib.jar $dest/libsignal_jni.so

   ###########################################################################
   # libsqlitejdbc.so
   ###########################################################################
   # getting version of included "libsqlitejdbc.so"
   sqllib=$(ls ./signal-cli-$versionsig/lib/sqlite-jdbc*.jar)
   versionsql=${sqllib##*/}
   versionsql=${versionsql:12:-4}
   versionsql_s=${versionsql:0:-2}
   echo " -> required version of the sqlite-jdbc library : v"$versionsql

   echo " -> getting sources"
   wget -q -P $dest "https://github.com/xerial/sqlite-jdbc/archive/refs/tags/$versionsql.tar.gz"
   cat "$dest/$versionsql.tar.gz" | tar -xzf - -i

   echo " -> compiling sources (needs about 2 minutes on a Raspi4)"
   make -C $dest/sqlite-jdbc-$versionsql clean  > /dev/null 2> /dev/null
   make -C $dest/sqlite-jdbc-$versionsql native > /dev/null 2> /dev/null

   echo " -> patching 'sqlite-jdbc-$versionsql.jar' with compiled sqlite-jdbc library"
   zip -d $dest/signal-cli-$versionsig/lib/sqlite-jdbc-$versionsql.jar org/sqlite/native/Linux/aarch64/libsqlitejdbc.so > /dev/null
   archivepath=org/sqlite/native/Linux/aarch64/libsqlitejdbc.so
   librarypath=$dest/sqlite-jdbc-$versionsql/target/sqlite-$versionsql_s-Linux-aarch64/libsqlitejdbc.so
   $SCRIPT_DIR/zipadd $dest/signal-cli-$versionsig/lib/sqlite-jdbc-$versionsql.jar $librarypath $archivepath

   ###########################################################################
   # be sure to use the required java version
   ###########################################################################
   echo " -> patching 'signal-cli' with information about the required java version "
   sed -i "3i $newLineOne\n$newLineTwo\n" $dest/signal-cli-$versionsig/bin/signal-cli

   ###########################################################################
   # creating new symbolic link
   ###########################################################################
   echo " -> creating symbolic link"
   ln -s $dest/signal-cli-$versionsig/bin/signal-cli /usr/local/bin/signal-cli

   ###########################################################################
   # clean up
   ###########################################################################
   echo " -> clean up"
   rm $dest/$signalfilename
   rm $dest/$libfilename
   rm $dest/libsignal_jni.so

   rm -r $dest/$versionsql.tar.gz
   rm -r $dest/sqlite-jdbc-$versionsql

   echo 
   echo " -> process successfully completed, new version : '$(signal-cli --version)'"
   echo 
fi

exit

