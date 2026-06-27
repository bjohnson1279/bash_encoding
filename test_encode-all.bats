#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of encode-all.sh
    RECORDING_PATH="dummy_path"
    DESTINATION_PATH="dummy_dest"

    # Source the script
    source encode-all.sh
}

@test "getDuration parses typical ffmpeg duration correctly" {
    ffmpeg() {
        echo "  Duration: 00:05:43.50, start: 0.000000, bitrate: 1234 kb/s"
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "05:43.50" ]
}

@test "getDuration parses duration with non-zero hours correctly" {
    ffmpeg() {
        echo "  Duration: 01:05:43.50, start: 0.000000, bitrate: 1234 kb/s"
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "01:05:43.50" ]
}

@test "getDuration handles empty output when no duration is found" {
    ffmpeg() {
        echo "  Some other output without duration"
    }

    result=$(getDuration "dummy.ts")
    [ -z "$result" ]
}

@test "getDuration parses duration without leading zero hours correctly" {
    ffmpeg() {
        echo "  Duration: 02:30:15.00, start: 0.000000, bitrate: 1234 kb/s"
    }

    result=$(getDuration "dummy.ts")
    [ "$result" = "02:30:15.00" ]
}
