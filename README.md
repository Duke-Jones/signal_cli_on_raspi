# signalupdate.sh
This script automatically installs or updates the Signal command line client on a Raspberry with Raspberry Pi OS (Raspian).

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

