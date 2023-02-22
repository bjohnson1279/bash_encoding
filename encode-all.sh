#!/bin/bash

clear 

# Enter location of local folder where Plex recordings are stored
RECORDING_PATH=""

# Enter location where encode files will be stored
DESTINATION_PATH=""

# FFMPEG encoder to be used
ENC_TYPE="libx264"

# Video filters applied, default yadif for deinterlacing
VF="yadif"

# Speed of encoding process, default veryslow to preserve disk space
PRESET="veryslow"

# Quality level, default 22
QUALITY=22

# Delete original file after encoding is complete? Set to 1 for YES
DEL_ORIG=1

# Function to obtain length of video
getDuration() {
    ffmpeg -i "${1}" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,// | sed s/00://
}

if [ -d "${RECORDING_PATH}" ]; then
    cd "${RECORDING_PATH}" || continue
    file_count=`ls -A 2>/dev/null | wc -l`
    if [ $file_count != 0 ]
    then
        # Iterate through all directories in folder containing your recordings
        for dir in */; do
            echo "${dir}"

            # Validate directory exists, in case folder was deleted after list was obtained
            if [[ -d "${dir}" ]]; then
                cd "${dir}" || continue

                # Get number of folders in directory (Seasons)
                dir_file_count=`ls -A 2>/dev/null | wc -l`
                echo "${dir} directory file count: ${dir_file_count}"

                if [ $dir_file_count != 0 ]; then
                    # Iterate through Season folders
                    for season in */; do
                        echo "${season}"
                        if [ -d "${season}" ]; then
                            cd "${season}" || continue
                            
                            # Get number of .ts files found in Season directory
                            ts_dir_file_count=`ls -A *.ts 2>/dev/null | wc -l`
                            echo "${season} ts file count: ${ts_dir_file_count}"

                            if [ $ts_dir_file_count != 0 ]; then
                                for i in *.ts; do
                                    echo "${i}"
                                    # Get video duration of encoding source
                                    src_duration=$(getDuration "${i}")
                                    src_duration="${src_duration%.*}"

                                    # Apply pattern matching to remove extraneous data in file name
                                    # Removes year, dashes, and adds space between season and episode number
                                    shopt -s extglob
                                    new_file=${i//\(*\) /}}
                                    new_file=${new_file//- /}}
                                    new_file=${new_file/E/ E}
                                    new_file=${new_file%.*}
                                    echo "New File: ${new_file}"
                                    new_file_full="${DESTINATION_PATH}${new_file}.mp4"

                                    # Validate existience of file
                                    if [ -f "${i}" ]; then
                                        # Skip if encoded file already exists, encode if not
                                        if [ ! -f "${new_file_full}" ]; then
                                            # Check for optional video filter
                                            if [ $VF != "" ]; then
                                                ffmpeg -i "${i}" \
                                                    -vf $VF \
                                                    -c:v $ENC_TYPE -c:a copy \
                                                    -pix_fmt yuv420p \
                                                    -tune film \
                                                    -movflags use_metadata_tags \
                                                    -preset $PRESET \
                                                    -crf $QUALITY \
                                                    "${new_file_full}"
                                            else
                                                ffmpeg -i "${i}" \
                                                    -c:v $ENC_TYPE -c:a copy \
                                                    -pix_fmt yuv420p \
                                                    -tune film \
                                                    -movflags use_metadata_tags \
                                                    -preset $PRESET \
                                                    -crf $QUALITY \
                                                    "${new_file_full}"
                                            fi
                                        fi

                                        # OPTIONAL: Delete source (ts) file when new file (mp4) is created, for space saving purposes
                                        # Set DEL_ORIG value to 0 above if you don't want this to happen
                                        if [ $DEL_ORIG == 1 ]; then
                                            dest_duration=$(getDuration "${new_file_full}")
                                            dest_duration="${dest_duration%.*}"
                                            echo "dest_duration: ${dest_duration}"

                                            echo "Source File Duration: ${src_duration}"
                                            echo "Destination File Duration: ${dest_duration}"

                                            if [ "${src_duration}" == "${dest_duration}" ]; then
                                                rm "${i}"
                                            fi
                                        fi
                                    fi
                                    shopt -u extglob
                                done # END for loop for ts files in directory
                            fi

                            # Done with directory, go one up to move on to next
                            cd ..
                        fi
                    done # END for loop for Season directories
                fi

                # Go back to recording path to move on to the next show
                cd "${RECORDING_PATH}"
            fi
        done # END for loop for all TV show directories
    fi
fi
