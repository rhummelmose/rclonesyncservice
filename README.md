# rclonesyncservice
Bash shell script for continuous, safe synchronization from paths on a mounted volume to an rclone remote.
## Installation
Install using Homebrew from command line:
```bash
$ brew install rhummelmose/formulae/rclonesyncservice
```
## Usage
Use rclonesyncservice from command line:
```bash
$ rclonesyncservice --frequency 5 --source Drobo5N --destination GSuite --paths "Movies, Movies (Temp), TV Shows, TV Shows (Temp)"
```
The above command will continuously synchronize the **paths** *Movies*, *Movies (Temp)*, *TV Shows* and *TV Shows (Temp)*, from a mounted **source** volume for which the path contains the string *Drobo5N* to a **destination** rclone remote called *GSuite*. After synchronization it will pause for *5* seconds, because we passed the **frequency** argument, that will otherwise default to 60 seconds.
