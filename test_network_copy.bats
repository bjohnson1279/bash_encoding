#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/network-copy.sh"
}

@test "get_avail_mb calculates correct mb from df output" {
    df() {
        echo "Filesystem     1024-blocks    Used Available Capacity Mounted on"
        echo "/dev/disk1s1s1  976490576 439054760 537435816    45% /"
    }

    run get_avail_mb "."
    [ "$status" -eq 0 ]
    [ "$output" = "524839" ] # 537435816 / 1024 = 524839.664... -> 524839
}

@test "get_avail_mb fails if target directory does not exist" {
    run get_avail_mb "/non/existent/directory/that/should/not/exist/ever"
    [ "$status" -eq 1 ]
}

@test "get_avail_mb uses current directory as default" {
    df() {
        echo "Filesystem     1024-blocks    Used Available Capacity Mounted on"
        echo "/dev/disk1s1s1  976490576 439054760 1024000    45% /"
    }

    run get_avail_mb
    [ "$status" -eq 0 ]
    [ "$output" = "1000" ]
}
