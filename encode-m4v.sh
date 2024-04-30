# Encode all .m4v files in a directory 
for i in *.m4v; do ffmpeg -i "$i" -vf yadif -c:v libx264 -preset veryslow -pix_fmt yuv420p -crf 21 -movflags faststart -y "${i%.*}.mp4"; done
