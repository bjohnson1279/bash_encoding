#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of encode-all.sh
    RECORDING_PATH="dummy_path"
    DESTINATION_PATH="dummy_dest"

    # Source the script
    source encode-all.sh
}

@test "getDuration parses typical ffmpeg format duration correctly" {
    ffprobe() {
        echo 'format.duration="05:43.50"'
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "05:43.50" ]
}

@test "getDuration parses typical ffmpeg stream duration correctly" {
    ffprobe() {
        echo 'streams.stream.0.duration="01:05:43.50"'
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "01:05:43.50" ]
}

@test "getDuration handles empty output when no duration is found" {
    ffprobe() {
        echo ""
    }

    result=$(getDuration "dummy.ts")
    [ -z "$result" ]
}

@test "getDuration parses format duration without leading zero hours correctly over stream" {
    ffprobe() {
        echo 'streams.stream.0.duration="02:30:16.00"'
        echo 'format.duration="02:30:15.00"'
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "02:30:15.00" ]
}
