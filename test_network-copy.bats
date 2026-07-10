#!/usr/bin/env bats

setup() {
    # Provide dummy values to skip main execution logic of network-copy.sh
    # Not strictly necessary if we guarded it, but good practice
    MNT_SHARE_PATH="dummy_path"
    LOCAL_SHARE_PATH="dummy_local"
    RECORDING_PATH="dummy_rec"

    source network-copy.sh
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
