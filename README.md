# spotify-reverse-albums
This Linux bash script reverses the albums of an artist.
It creates a new playlist with all the albums reversed.
This is convenient when you want to play the albums with oldest first (Spotify ususally sorts newest first)

Just invoke the script reverse-albums.sh to get the usage information.

The script uses the [Spotify REST API](https://developer.spotify.com/web-api/). Therefore it requires curl and a few other (standard) binaries. The script will check for these pre-reqs.

Pure bash-ish, no need for temp files etc.

On Mac you will need homebrew and install the following packages: coreutils, findutils and jq.
Also make sure their directories are in front of your PATH by adding this to your ${HOME}/.bashrc
```
# add GNU coreutils and findutils in front of the PATH
export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/opt/findutils/libexec/gnubin:${PATH}
```

On Windows you will need WSL (Windows Subsystem for Linux), see:  https://docs.microsoft.com/en-us/windows/wsl/

An example (all Pink Floyd albums reversed): https://open.spotify.com/playlist/0pxxJlaPquHTvtVfskhJiB

