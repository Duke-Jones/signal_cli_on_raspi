#!/bin/bash

if [ ! -z "$1" ] && [ ! -z "$2" ]; then
   login="-u $1:$2"
fi


###########################################################################
# helper function: asking for yes/no input
###########################################################################
function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) echo 1 ; return  ;;
            [Nn]*) echo 0 ; return  ;;
        esac
    done
}


###########################################################################
# helper function: change existing zip archive
###########################################################################
zipadd() {
python -c '
import zipfile as zf, sys
z=zf.ZipFile(sys.argv[1], "a")
z.write(sys.argv[2], sys.argv[3])
z.close()' $1 $2 $3
}

###########################################################################
# helper function: install required alternative java version
###########################################################################
installjava() {
   java_root=/usr/lib/jvm
   java_dest=java-21.0.2-openjdk-arm64
   java_lns=java-21-openjdk-arm64

   mkdir -p /tmp/openjdk21_install
   mkdir -p "$java_root/$java_dest/"


   wget -O /tmp/openjdk21_install/openjdk-21.0.2_linux-aarch64_bin.tar.gz https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-aarch64_bin.tar.gz

   echo "$java_root/$java_dest/"
   tar xvzf /tmp/openjdk21_install/openjdk-21.0.2_linux-aarch64_bin.tar.gz --strip-components=1 -C "$java_root/$java_dest/"

   cd "$java_root"
   ln -r -s "$java_dest" "$java_lns"

   update-alternatives --install /usr/bin/java  java  "$java_root/$java_lns/bin/java"  500
   update-alternatives --install /usr/bin/javac javac "$java_root/$java_lns/bin/javac" 500

   rm -r /tmp/openjdk21_install
}



SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

systemarch=$(uname -m)
#echo "${systemarch:0:5}"
if [ "${systemarch:0:5}" != "armv7" ] && [ "$systemarch" != "aarch64" ]; then
   echo "untestet architecture ($systemarch) - I'll better stop here !" 1>&2
   exit
fi

# required signal library type
arch=armv7-unknown-linux-gnueabihf
#arch=aarch64-unknown-linux-gnu
# java version
req_java_v=21

# installation destination
dest=/usr/local/signal
java_required=false

###########################################################################
# root check
###########################################################################
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root!" 1>&2
  echo
  exit 1
fi

###########################################################################
# checking latest version of signal-cli and decide if installation is required
###########################################################################
# get Filename of the last version of signal-cli

suffix="-Linux"
signalfile=$(curl $login -s https://api.github.com/repos/AsamK/signal-cli/releases/latest | jq -r ".assets[] | select(.name | test(\"signal-cli-.*$suffix.tar.gz$\")) | .browser_download_url" | grep -E "signal-cli-([0-9]{1,2}\.?){3}$suffix\.tar\.gz$")
if [ "$signalfile" == "" ]; then
   suffix=""
   signalfile=$(curl $login -s https://api.github.com/repos/AsamK/signal-cli/releases/latest | jq -r ".assets[] | select(.name | test(\"signal-cli-.*$suffix.tar.gz$\")) | .browser_download_url" | grep -E "signal-cli-([0-9]{1,2}\.?){3}$suffix\.tar\.gz$")
fi

if [ "$signalfile" == "" ]; then
   echo " -> no matching archive found on 'https://api.github.com/repos/AsamK/'"
   echo " -> exiting - bye bye"
   exit
fi

suffixlength=${#suffix}
signalfilename=${signalfile##*/}

# extract version string
versionsig=${signalfile##*/}
cut=
versionsig=${versionsig:11:-$((7+$suffixlength))}
#echo $versionsig
echo " -> new client version     : v$versionsig"

same_version=0

# now get the current installed version
currentversionfile=$(find /usr/local/bin/ -maxdepth 1 -name signal-cli)
if [ -z "$currentversionfile" ]; then
   answer="$(yes_or_no ' -> no current installation found -> installing signal-cli now ?')"
   if [ $answer -eq 0 ]; then
      echo " -> exiting - bye bye"
      exit
   fi
else
   currentversionfile=$(echo "$currentversionfile" | xargs readlink -f)
   currentversionfull=$(echo "$currentversionfile" | cut -f5 --delimiter='/')
   current_path=$(echo "$currentversionfile" | cut -f1-5 --delimiter='/')
   currentversion=${currentversionfull:11}

   echo " -> current client version : v$currentversion"

   if [ "$versionsig" == "$currentversion" ]; then
      answer="$(yes_or_no ' -> the versions are the same - install anyway ?')"
      if [ $answer -eq 0 ]; then
         echo " -> exiting - bye bye"
         exit
      fi
      same_version=1
   else
      answer="$(yes_or_no ' -> older version found - installing new signal-cli now ?')"
      if [ $answer -eq 0 ]; then
         echo " -> exiting - bye bye"
         exit
      fi
   fi
fi

###########################################################################
# java check
###########################################################################
install_java=false
java_major=$(java --version | head -n 1 | cut -f2 --delimiter=' ' | cut -f1 --delimiter='.')
java_alt=$(update-alternatives --list java | grep java-$req_java_v | head -n 1 | cut -f1 --delimiter=' ')
if [ "$java_alt" != "" ]; then
   java_alt_major=$($java_alt --version | head -n 1 | cut -f2 --delimiter=' ' | cut -f1 --delimiter='.')
fi

if [ "$java_major" == "" ]; then

    answer="$(yes_or_no ' -> java: no java found - install openjdk-21 ?')"
    if [ $answer -eq 1 ]; then
        installjava
        hasjava=true
    else
        echo " -> java: no version found - I will stop here"
        echo "    you must install \'java-$req_java_v-openjdk\' or higher"
        echo " -> exiting - bye bye"
        exit
    fi
elif [ $java_major -lt $req_java_v ]; then
    if [ "$java_alt_major" != "" ] && [ $java_alt_major -ge $req_java_v ]; then
        has_java_alt=true
    else
        answer="$(yes_or_no ' -> java: no java-21 found - install openjdk-21 as alternative version ?')"
        if [ $answer -eq 1 ]; then
            installjava
            has_java_alt=true
        else
            echo " -> java: existing version too old - I will stop here"
            echo "    you can upgrade to java-$req_java_v-openjdk or you can install java-17-openjdk as an alternative (see 'update-alternatives')"
            echo " -> exiting - bye bye"
            exit
        fi
    fi
else
   hasjava=true
fi

echo 1 $JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64
echo 2 $JAVA_HOME

   ###########################################################################
   # starting installation routine
   ###########################################################################

   # goto the destination directory
   if [ ! -d "$dest" ]; then
      mkdir -p $dest
   fi
   cd $dest


   ###########################################################################
   # backup
   ###########################################################################
   # make a backup of the existing installation if the version stay the same 
   if [ "$same_version" -eq 1 ]; then
      cur_count=$(find $dest/ -maxdepth 1 -type d -iname "${currentversionfull}_*" | wc -l)
      cur_count=$(($cur_count + 1))

      mv ${current_path} ${current_path}_${cur_count}
   fi


   ###########################################################################
   # getting signal-cli 
   ###########################################################################
   echo " -> downloading new client"
   wget -q -P $dest $signalfile
   cat "$dest/$signalfilename" | tar -xzf - -i


   ###########################################################################
   # getting libsignal_jni.so for raspberry
   # (general needed, because signal-cli doesn't support Rasperry directly)
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

   if [ "$systemarch" = "aarch64" ]; then
      ###########################################################################
      # getting libsqlitejdbc.so
      # ( only needed on aarch64 )
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

      zip -d $dest/signal-cli-$versionsig/lib/sqlite-jdbc-$versionsql.jar org/sqlite/native/Linux/aarch64/libsqlitejdbc.so #> /dev/null
      archivepath=org/sqlite/native/Linux/aarch64/libsqlitejdbc.so
      librarypath=$dest/sqlite-jdbc-$versionsql/target/sqlite-$versionsql_s-Linux-aarch64/libsqlitejdbc.so
      zipadd "$dest/signal-cli-$versionsig/lib/sqlite-jdbc-$versionsql.jar" "$librarypath" "$archivepath"
fi


   ###########################################################################
   # be sure to use the required java version
   ###########################################################################
   if [ "$has_java_alt" = true ]; then
      echo 1 $java_alt
      java_alt=${java_alt:0:-9}
      echo 2 $java_alt

      newLineOne="export JAVA_HOME=\"$java_alt\""
      newLineTwo="PATH=${JAVA_HOME}:$PATH"

      echo " -> patching 'signal-cli' with information about the required java version "
      sed -i "3i $newLineOne\n$newLineTwo\n" $dest/signal-cli-$versionsig/bin/signal-cli
   fi

   ###########################################################################
   # creating new symbolic link
   ###########################################################################
   if [ -f "/usr/local/bin/signal-cli" ]; then
      rm /usr/local/bin/signal-cli
   fi

   echo " -> creating symbolic link"
   ln -s $dest/signal-cli-$versionsig/bin/signal-cli /usr/local/bin/signal-cli

   ###########################################################################
   # clean up
   ###########################################################################
   echo " -> clean up"
   rm $dest/$signalfilename
   rm $dest/$libfilename
   rm $dest/libsignal_jni.so

   if [ "$systemarch" = "aarch64" ]; then
      rm -r $dest/$versionsql.tar.gz
      rm -r $dest/sqlite-jdbc-$versionsql
   fi

   echo
   echo " -> process successfully completed, new version : '$(signal-cli --version)'"
   echo



