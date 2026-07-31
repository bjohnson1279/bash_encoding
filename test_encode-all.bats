#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of encode-all.sh
    # We must patch the script in memory to allow setting variables dynamically,
    # since encode-all.sh sets DESTINATION_PATH natively at the top.
    # However, a simpler way is to just let bash execute it up to the point of exit by creating the actual default directory.
    export TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/dummy_dest"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "getDuration parses typical ffmpeg format duration correctly" {
    ffprobe() {
        echo 'format.duration="05:43.50"'
    }
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "05:43.50" ]
}

@test "getDuration parses typical ffmpeg stream duration correctly" {
    ffprobe() {
        echo 'streams.stream.0.duration="01:05:43.50"'
    }
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "01:05:43.50" ]
}

@test "getDuration handles empty output when no duration is found" {
    ffprobe() {
        echo ""
    }
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ -z "$result" ]
}

@test "getDuration parses format duration without leading zero hours correctly over stream" {
    ffprobe() {
        echo 'streams.stream.0.duration="02:30:16.00"'
        echo 'format.duration="02:30:15.00"'
    }
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(getDuration "dummy.ts")
    [ "$result" = "02:30:15.00" ]
}

@test "parseFilename parses standard show name with year, season, episode, title, and datetime" {
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(parseFilename "The Show Name (2020) - S02E05 - The Episode Title (2020-01-01 20 00 00).ts")
    show=$(echo "$result" | jq -r '.show')
    season=$(echo "$result" | jq -r '.season')
    episode=$(echo "$result" | jq -r '.episode')
    title=$(echo "$result" | jq -r '.title')
    premiered=$(echo "$result" | jq -r '.premiered')
    [ "$show" = "The Show Name" ]
    [ "$season" = "02" ]
    [ "$episode" = "05" ]
    [ "$title" = "The Episode Title" ]
    [ "$premiered" = "2020" ]
}

@test "parseFilename parses standard show name with year, season, episode, pilot title, and datetime without hyphens" {
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(parseFilename "Another Show (2019) S01E01 Pilot (2019-10-10 10 10 10).ts")
    show=$(echo "$result" | jq -r '.show')
    season=$(echo "$result" | jq -r '.season')
    episode=$(echo "$result" | jq -r '.episode')
    title=$(echo "$result" | jq -r '.title')
    premiered=$(echo "$result" | jq -r '.premiered')
    [ "$show" = "Another Show" ]
    [ "$season" = "01" ]
    [ "$episode" = "01" ]
    [ "$title" = "Pilot" ]
    [ "$premiered" = "2019" ]
}

@test "parseFilename parses movie format with year" {
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(parseFilename "Movie Name (2022).ts")
    show=$(echo "$result" | jq -r '.show')
    season=$(echo "$result" | jq -r '.season')
    episode=$(echo "$result" | jq -r '.episode')
    title=$(echo "$result" | jq -r '.title')
    premiered=$(echo "$result" | jq -r '.premiered')
    [ "$show" = "Movie Name" ]
    [ "$season" = "" ]
    [ "$episode" = "" ]
    [ "$title" = "" ]
    [ "$premiered" = "2022" ]
}

@test "parseFilename correctly escapes double quotes" {
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(parseFilename 'Show With "Quotes" (2023) - S01E02 - Title "Quotes" (2023-01-01 12 00 00).ts')
    show=$(echo "$result" | jq -r '.show')
    season=$(echo "$result" | jq -r '.season')
    episode=$(echo "$result" | jq -r '.episode')
    title=$(echo "$result" | jq -r '.title')
    premiered=$(echo "$result" | jq -r '.premiered')
    [ "$show" = 'Show With "Quotes"' ]
    [ "$season" = "01" ]
    [ "$episode" = "02" ]
    [ "$title" = 'Title "Quotes"' ]
    [ "$premiered" = "2023" ]
}

@test "parseFilename correctly escapes backslashes" {
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(parseFilename 'Show with \ Backslash (2023) - S01E02 - Title \ Backslash (2023-01-01 12 00 00).ts')
    show=$(echo "$result" | jq -r '.show')
    season=$(echo "$result" | jq -r '.season')
    episode=$(echo "$result" | jq -r '.episode')
    title=$(echo "$result" | jq -r '.title')
    premiered=$(echo "$result" | jq -r '.premiered')
    [ "$show" = 'Show with \ Backslash' ]
    [ "$season" = "01" ]
    [ "$episode" = "02" ]
    [ "$title" = 'Title \ Backslash' ]
    [ "$premiered" = "2023" ]
}

@test "parseFilename correctly escapes newlines" {
    source <(sed "s|DESTINATION_PATH=\"/path/to/encoded\"|DESTINATION_PATH=\"$TEST_TEMP_DIR/dummy_dest\"|" encode-all.sh) || true
    result=$(parseFilename $'Show With Newline\n (2023) - S01E02 - Title\nNewline (2023-01-01 12 00 00).ts')
    show=$(echo "$result" | jq -r '.show')
    season=$(echo "$result" | jq -r '.season')
    episode=$(echo "$result" | jq -r '.episode')
    title=$(echo "$result" | jq -r '.title')
    premiered=$(echo "$result" | jq -r '.premiered')
    [ "$show" = $'Show With Newline' ]
    [ "$season" = "01" ]
    [ "$episode" = "02" ]
    [ "$title" = $'Title\nNewline' ]
    [ "$premiered" = "2023" ]
}
