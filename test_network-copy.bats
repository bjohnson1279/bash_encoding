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

@test "get_avail_mb fails safely on non-numeric injection" {
    df() {
        echo "Filesystem     1024-blocks   Used Available Capacity Mounted on"
        echo "/dev/sda1          1000000 500000      a[\$(echo 1 > /tmp/hacked)]      50% /mock/path"
    }
    mkdir -p /tmp/mock_dir
    rm -f /tmp/hacked

    result=$(get_avail_mb "/tmp/mock_dir")
    [ "$result" -eq 0 ]
    [ ! -f /tmp/hacked ]

    rm -rf /tmp/mock_dir
    rm -f /tmp/hacked
}

@test "get_folder_size_mb fails safely on non-numeric injection" {
    du() {
        echo "a[\$(echo 1 > /tmp/hacked)]	/mock/path"
    }
    rm -f /tmp/hacked

    result=$(get_folder_size_mb "/mock/path")
    [ "$result" -eq 0 ]
    [ ! -f /tmp/hacked ]

    rm -f /tmp/hacked
}
