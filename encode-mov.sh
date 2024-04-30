# Encode all .mov files in a directory 
for i in *.mov; do ffmpeg -i "$i" -vf yadif -c:v libx264 -preset veryslow -pix_fmt yuv420p -crf 21 -y "${i%.*}.mp4"; done
