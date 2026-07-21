#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of network-copy.sh
    # Not strictly necessary if we guarded it, but good practice
    MNT_SHARE_PATH="dummy_path"
    LOCAL_SHARE_PATH="dummy_local"
    RECORDING_PATH="dummy_rec"

    source network-copy.sh
}

@test "get_avail_mb returns 1 for invalid directory" {
    # Provide a clearly non-existent directory
    run get_avail_mb "/path/does/not/exist/123456789"
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
}

@test "get_avail_mb calculates available MB correctly" {
    # Mock df to output 2048 1K-blocks (which is exactly 2 MB)
    df() {
        echo "Filesystem     1024-blocks   Used Available Capacity Mounted on"
        echo "/dev/sda1          1000000 500000      2048      50% /mock/path"
    }

    # Create a dummy directory to pass the directory check
    mkdir -p /tmp/mock_dir

    result=$(get_avail_mb "/tmp/mock_dir")
    [ "$result" -eq 2 ]

    # Cleanup
    rm -rf /tmp/mock_dir
}

@test "get_folder_size_mb calculates standard MB correctly" {
    # Mock du to output 1024 1K-blocks (which is exactly 1 MB)
    du() {
        echo "1024	/mock/path"
    }

    result=$(get_folder_size_mb "/mock/path")
    [ "$result" -eq 1 ]
}

@test "get_folder_size_mb rounds down appropriately" {
    # Mock du to output 1500 1K-blocks (1.46 MB, rounds down to 1 in int division)
    du() {
        echo "1500	/mock/path"
    }

    result=$(get_folder_size_mb "/mock/path")
    [ "$result" -eq 1 ]
}

@test "get_folder_size_mb returns 0 for sizes less than 1MB" {
    # Mock du to output 500 1K-blocks (0.48 MB, rounds down to 0)
    du() {
        echo "500	/mock/path"
    }

    result=$(get_folder_size_mb "/mock/path")
    [ "$result" -eq 0 ]
}

@test "get_folder_size_mb calculates large folder sizes correctly" {
    # Mock du to output 1048576 1K-blocks (which is exactly 1024 MB or 1 GB)
    du() {
        echo "1048576	/mock/path"
    }

    result=$(get_folder_size_mb "/mock/path")
    [ "$result" -eq 1024 ]
}

@test "get_folder_size_mb calculates correctly with spaces in path" {
    # Mock du to output for a path with spaces
    du() {
        echo "2048	/mock/path with spaces"
    }

    result=$(get_folder_size_mb "/mock/path with spaces")
    [ "$result" -eq 2 ]
}

@test "folder_sync returns 1 and prints error when source directory does not exist" {
    run folder_sync "/path/does/not/exist/123" 1000
    [ "$status" -eq 1 ]
    [[ "${lines[0]}" == "Directory '/path/does/not/exist/123' not available." ]]
}

@test "folder_sync returns 1 when available space is less than required space" {
    # Mock get_avail_mb to return 500 (less than 1000 required)
    get_avail_mb() {
        echo 500
    }

    mkdir -p /tmp/mock_src_dir

    run folder_sync "/tmp/mock_src_dir" 1000
    [ "$status" -eq 1 ]
    [[ "${lines[1]}" == "Insufficient disk space to start copy from '/tmp/mock_src_dir'." ]]

    rm -rf /tmp/mock_src_dir
}

@test "folder_sync returns 1 when source folder size is greater than available space" {
    # Mock get_avail_mb to return 1500 (greater than 1000 required, but less than folder size)
    get_avail_mb() {
        echo 1500
    }

    # Mock get_folder_size_mb to return 2000 (greater than 1500 available)
    get_folder_size_mb() {
        echo 2000
    }

    mkdir -p /tmp/mock_src_dir

    run folder_sync "/tmp/mock_src_dir" 1000
    [ "$status" -eq 1 ]
    [[ "${lines[3]}" == "Insufficient disk space to copy '/tmp/mock_src_dir'." ]]

    rm -rf /tmp/mock_src_dir
}

@test "folder_sync successfully runs rsync when there is enough space" {
    # Mock get_avail_mb to return 2000
    get_avail_mb() {
        echo 2000
    }

    # Mock get_folder_size_mb to return 1500
    get_folder_size_mb() {
        echo 1500
    }

    # Mock rsync to do nothing but print a string so we can verify it was called
    rsync() {
        echo "mock rsync executed"
    }

    mkdir -p /tmp/mock_src_dir
    RECORDING_PATH="/tmp/mock_recording_path"

    run folder_sync "/tmp/mock_src_dir" 1000
    [ "$status" -eq 0 ]

    # Check that it outputs the correct final success message
    local has_mock_rsync=0
    local has_copy_complete=0

    for line in "${lines[@]}"; do
        if [[ "$line" == "mock rsync executed" ]]; then
            has_mock_rsync=1
        fi
        if [[ "$line" == "Copy complete." ]]; then
            has_copy_complete=1
        fi
    done

    [ "$has_mock_rsync" -eq 1 ]
    [ "$has_copy_complete" -eq 1 ]

    rm -rf /tmp/mock_src_dir
}
