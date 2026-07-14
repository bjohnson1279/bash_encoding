#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of encode-all.sh
    # We must patch the script in memory to allow setting variables dynamically,
    # since encode-all.sh sets DESTINATION_PATH natively at the top.
    # However, a simpler way is to just let bash execute it up to the point of exit by creating the actual default directory.
    mkdir -p "/tmp/dummy_dest"
}

@test "getDuration parses typical ffmpeg duration correctly" {
    ffprobe() {
        echo "05:43.50"
    }
    source <(sed 's/DESTINATION_PATH="\/path\/to\/encoded"/DESTINATION_PATH="\/tmp\/dummy_dest"/' encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "05:43.50" ]
}

@test "getDuration parses duration with non-zero hours correctly" {
    ffprobe() {
        echo "01:05:43.50"
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

@test "getDuration parses duration without leading zero hours correctly" {
    ffprobe() {
        echo "02:30:15.00"
    }
    source <(sed 's/DESTINATION_PATH="\/path\/to\/encoded"/DESTINATION_PATH="\/tmp\/dummy_dest"/' encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "02:30:15.00" ]
}
