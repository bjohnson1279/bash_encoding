#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of encode-all.sh
    # We must patch the script in memory to allow setting variables dynamically,
    # since encode-all.sh sets DESTINATION_PATH natively at the top.
    # However, a simpler way is to just let bash execute it up to the point of exit by creating the actual default directory.
    mkdir -p "/tmp/dummy_dest"
}

@test "getDuration parses typical ffmpeg format duration correctly" {
    ffprobe() {
        echo 'format.duration="05:43.50"'
    }
    source <(sed 's/DESTINATION_PATH="\/path\/to\/encoded"/DESTINATION_PATH="\/tmp\/dummy_dest"/' encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "05:43.50" ]
}

@test "getDuration parses typical ffmpeg stream duration correctly" {
    ffprobe() {
        echo 'streams.stream.0.duration="01:05:43.50"'
    }
    source <(sed 's/DESTINATION_PATH="\/path\/to\/encoded"/DESTINATION_PATH="\/tmp\/dummy_dest"/' encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "01:05:43.50" ]
}

@test "getDuration handles empty output when no duration is found" {
    ffprobe() {
        echo ""
    }
    source <(sed 's/DESTINATION_PATH="\/path\/to\/encoded"/DESTINATION_PATH="\/tmp\/dummy_dest"/' encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ -z "$result" ]
}

@test "getDuration parses format duration without leading zero hours correctly over stream" {
    ffprobe() {
        echo 'streams.stream.0.duration="02:30:16.00"'
        echo 'format.duration="02:30:15.00"'
    }
    source <(sed 's/DESTINATION_PATH="\/path\/to\/encoded"/DESTINATION_PATH="\/tmp\/dummy_dest"/' encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "02:30:15.00" ]
}
