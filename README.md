# signalupdate.sh
This script automatically installs or updates the signal command line client ([https://github.com/AsamK/signal-cli](https://github.com/AsamK/signal-cli "https://github.com/AsamK/signal-cli")) on a Raspberry with Raspberry Pi OS (Raspian).

## Procedure details
1. check for an existing version, backup if necessary
2. download the latest signal-cli ([https://github.com/AsamK/signal-cli](https://github.com/AsamK/signal-cli "https://github.com/AsamK/signal-cli"))
3. download corresponding library and patch signal-cli installation with it ([https://github.com/exquo/libsignal-client](https://github.com/exquo/libsignal-client "https://github.com/exquo/libsignal-client"))
4. (aarch64 only) download corresponding sources for libsqlitejdbc.so, compile and patch signal-cli installation with it ([https://github.com/xerial/sqlite-jdbc](https://github.com/xerial/sqlite-jdbc "https://github.com/xerial/sqlite-jdbc"))

## File locations
- downloaded files and binaries:
`/usr/local/signal/`
- symbolic link : 
`/usr/local/bin/signal-cli`

## Usage
simply execute the script file :
  ```bash
sudo bash signalupdate.sh
```

## Requirements
* RaspberryPi with "armv7(l)" or "aarch64" (only tested on Raspi4B).
* installed package "wget
* installed package "java-17-openjdk" (as primary or alternative java version, if the primary version of java has to be a different one --> see 'update-alternatives')
* helperfile "zipadd"

## Example run
    user@system:~/signal_cli_on_raspi $ sudo bash signalupdate.sh 
    
     -> new client version     : v0.12.2
     -> current client version : v0.12.2
     -> the versions are the same - install anyway ? [y/n]: y
     -> backup old signal directory into '/usr/local/signal/backup_20231007_214922'
     -> downloading new client
     -> required version of the libsignal library (armv7-unknown-linux-gnueabihf) : v0.32.1
     -> patching 'libsignal-client-0.12.2.jar' with customised libsignal library
     -> required version of the sqlite-jdbc library : v3.43.0.0
     -> getting sources
     -> compiling sources (needs about 2 minutes on a Raspi4)
     -> patching 'sqlite-jdbc-3.43.0.0.jar' with compiled sqlite-jdbc library
     -> patching 'signal-cli' with information about the required java version 
     -> creating symbolic link
     -> clean up
    
     -> process successfully completed, new version : 'signal-cli 0.12.2'
    

