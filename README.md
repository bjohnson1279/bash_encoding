# bash_encoding
Collection of Bash scripts for encoding or re-encoding videos, with an emphasis on Plex DVR recordings. 

These started off as scripts to help me automate processes with my Plex DVR recordings.  I have an older machine dedicated to just the recordings, which I later offload to other (faster) machines with more hard drive space to re-encode to h.264 to stash in my main library.

As of right now, network-copy.sh is a refactored version of the script I've been using to copy my recordings over, and encode-all.sh is the script that iterates through all of the recordings and re-encodes them to h.264, with an optional setting to remove the original, assuming the encoded file comes out to the same length.

## `network-copy.sh`

Here is an example of how to configure `network-copy.sh` to copy a specific TV show:

```shell
# Example 1: Copying a specific TV show
# ------------------------------------------
# Source directory on the mounted share
recordings_src="$LOCAL_SHARE_PATH/Recorded TV Shows/Seinfeld (1989)"
# Required disk space in MB to check before starting
required_space_seinfeld=2500
folder_sync "$recordings_src" "$required_space_seinfeld"
```
