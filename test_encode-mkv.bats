#!/usr/bin/env bats

setup() {
    # Create a temporary test directory
    export TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary test directory
    rm -rf "$TEST_TEMP_DIR"
}

@test "encode-mkv.sh encodes multiple .mkv files correctly" {
    # Setup dummy files
    touch "$TEST_TEMP_DIR/file1.mkv"
    touch "$TEST_TEMP_DIR/file2.mkv"

    # Run the script in a subshell in the test directory
    (
        cd "$TEST_TEMP_DIR"

        # Mock ffmpeg to just record arguments
        ffmpeg() {
            echo "ffmpeg $@" >> "${TEST_TEMP_DIR}/ffmpeg_calls.log"
        }
        export -f ffmpeg

        # Source the script so it uses the mocked ffmpeg
        source "${BATS_TEST_DIRNAME}/encode-mkv.sh"
    )

    # Verify that ffmpeg was called twice
    run grep -c "^ffmpeg" "${TEST_TEMP_DIR}/ffmpeg_calls.log"
    [ "$status" -eq 0 ]
    [ "$output" -eq 2 ]

    # Verify some ffmpeg arguments for file1
    run grep "./file1.mkv" "${TEST_TEMP_DIR}/ffmpeg_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-i ./file1.mkv"* ]]
    [[ "$output" == *"-c:v libx264"* ]]
    [[ "$output" == *"-y ./file1.mp4"* ]]

    # Verify some ffmpeg arguments for file2
    run grep "./file2.mkv" "${TEST_TEMP_DIR}/ffmpeg_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-i ./file2.mkv"* ]]
    [[ "$output" == *"-c:v libx264"* ]]
    [[ "$output" == *"-y ./file2.mp4"* ]]
}

@test "encode-mkv.sh handles filenames with spaces correctly" {
    # Setup dummy file with spaces
    touch "$TEST_TEMP_DIR/file with spaces.mkv"

    # Run the script
    (
        cd "$TEST_TEMP_DIR"

        # Mock ffmpeg
        ffmpeg() {
            echo "ffmpeg $@" >> "${TEST_TEMP_DIR}/ffmpeg_calls.log"
        }
        export -f ffmpeg

        source "${BATS_TEST_DIRNAME}/encode-mkv.sh"
    )

    # Verify that ffmpeg was called
    run grep -c "^ffmpeg" "${TEST_TEMP_DIR}/ffmpeg_calls.log"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]

    # Verify ffmpeg arguments handled the spaces correctly
    run grep "./file with spaces.mkv" "${TEST_TEMP_DIR}/ffmpeg_calls.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-i ./file with spaces.mkv"* ]]
    [[ "$output" == *"-y ./file with spaces.mp4"* ]]
}

@test "encode-mkv.sh does not call ffmpeg when no .mkv files are present" {
    # Setup a dummy non-mkv file
    touch "$TEST_TEMP_DIR/file.txt"

    # Run the script
    (
        cd "$TEST_TEMP_DIR"

        ffmpeg() {
            echo "ffmpeg $@" >> "${TEST_TEMP_DIR}/ffmpeg_calls.log"
        }
        export -f ffmpeg

        source "${BATS_TEST_DIRNAME}/encode-mkv.sh"
    )

    # Verify that ffmpeg was not called (log file shouldn't exist)
    [ ! -f "${TEST_TEMP_DIR}/ffmpeg_calls.log" ]
}
