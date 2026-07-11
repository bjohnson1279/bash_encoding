#!/bin/bash
sudo mkdir -p /path/to/encoded /path/to/recordings
sudo chown -R $USER:$USER /path/to/encoded /path/to/recordings
source encode-all.sh
parseFilename 'foo\bar'
