#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of encode-all.sh
    RECORDING_PATH="dummy_path"
    DESTINATION_PATH="dummy_dest"

    # Source the script
    source encode-all.sh
}

@test "getDuration parses typical ffmpeg duration correctly" {
    ffprobe() {
        echo "05:43.50"
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "05:43.50" ]
}

@test "getDuration parses duration with non-zero hours correctly" {
    ffprobe() {
        echo "01:05:43.50"
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

@test "getDuration parses duration without leading zero hours correctly" {
    ffprobe() {
        echo "02:30:15.00"
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "02:30:15.00" ]
}
