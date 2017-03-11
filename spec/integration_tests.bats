load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load '../node_modules/bats-file/load'

setup() {
    rm -rf tmp
    mkdir tmp
    cd tmp
}

teardown() {
    # Ensure nothing unexpected was written (avoid leading spaces in `wc -l`
    # output: http://stackoverflow.com/a/30927885)
    ls | wc -l | {
        run sed 's/^ *//'
        assert_output 0
    }
}

gziprb() {
    bundle exec ../exe/gziprb "$@"
}

gunziprb() {
    bundle exec ../exe/gunziprb "$@"
}

assert_success_with_output() {
    assert_success
    assert_output "$1"
}

input="foo bar baz"

@test "compressing with gziprb and decompressing with gunziprb over stdin" {
    echo "$input" | gziprb | {
        run gunziprb
        assert_success_with_output "$input"
    }
}

@test "compressing with gzip and decompressing with gunziprb over stdin" {
    echo "$input" | gzip | {
        run gunziprb
        assert_success_with_output "$input"
    }
}

@test "compressing with gziprb and decompressing with gunzip over stdin" {
    echo "$input" | gziprb | {
      run gunzip
      assert_success_with_output "$input"
    }
}

@test "compressing a file with gziprb" {
    echo "$input" > input_file

    run gziprb input_file
    assert_success_with_output ""
    assert_file_exist input_file.gz

    run gunzip --stdout input_file.gz
    assert_success_with_output "$input"

    rm input_file{,.gz}
}

@test "decompressing a file that has a name header with gziprb" {
    echo "$input" > input_file
    gzip input_file

    run gunziprb input_file.gz
    assert_success_with_output ""

    run cat input_file
    assert_success_with_output "$input"

    rm input_file{,.gz}
}

@test "decompressing a renamed file that has a name header with gziprb" {
    echo "$input" > input_file
    gzip input_file
    mv {,other_}input_file.gz

    run gunziprb other_input_file.gz
    assert_success_with_output ""

    run cat input_file
    assert_success_with_output "$input"

    rm other_input_file.gz input_file
}

@test "decompressing a file that has no name header with gziprb" {
    echo "$input" | gzip > input_file.gz

    run gunziprb input_file.gz
    assert_success_with_output ""
    assert_file_exist input_file

    rm input_file{,.gz}
}

@test "it shows help on demand" {
    if [[ $(bundler --version) == *1.12.1 ]]; then
      skip "Bundler 1.12.1 incorrectly shows help for bundler not gziprb!"
    fi

    run gziprb --help
    assert_output --partial "Usage:"
}
