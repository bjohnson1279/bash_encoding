# Encode all .ts video files in a directory, usually Plex DVR recordings
for i in *.ts; do ffmpeg -i "$i" -vf yadif -c:v libx264 -preset veryslow -pix_fmt yuv420p -crf 21 -movflags faststart -y "${i%.*}.mp4"; done
