#!/bin/bash
set -eou pipefail
#
# Tests for development environment -- assume that this is running on a local
# machine (and thus BOSH isnt available, just the regular DNS lookup).
# It is assumed that this is running relative to the git root for the repo.

[[ ! -d tests ]] && echo "Please run from the root repo" && exit 1
[[ ! -f boshdns.py ]] && echo "Please run from the root repo" && exit 1

[[ ! -d results ]] && mkdir results

# simple global variable setup
DEBUG=${DEBUG:-''}
FAST_PID=''

# support applications needed
set +e
FASTAPI=$(type -p fastapi)
[[ -z "$FASTAPI" ]] && echo "Expect to find 'fastapi' available" && exit 1
set -e
CURL=$(type -p curl)
set +e
[[ -z "$CURL" ]] && echo "Need curl to run tests" && exit 1
set -e
JQ=$(type -p jq)
set +e
[[ -z "$JQ" ]] && echo "Need jq to run tests" && exit 1
set -e

# support
function clean_shut() {
    # shut down cleanly
    echo -n "killing fastapi "
    if [[ -n "$FAST_PID" ]] && [[ -d "/proc/$FAST_PID" ]]; then
	kill -9 "$FAST_PID"
    fi
    echo "ok"
}
trap clean_shut EXIT

# utilities
function debug_log () {
    if [[ -n "$DEBUG" ]]; then
	echo "$1"
    fi
}

function err_log () {
    echo -e "error: $1"
    exit 1
}

function logn () {
    echo -en "$1"
}

function log () {
    echo -e "$1"
}

# functional support
function are_gt () {
    msg="$1"
    want="$2"
    have="$3"
    if [[ "$have" -ge "$want" ]]; then
	log "$msg ok"
    else
	err_log "$msg, $have is not gt $want"
    fi
}

function get_results () {
    FIELD="$1"
    FILE="$2"
    $JQ -Mr "$FIELD" "$FILE"
}

function get_results_len () {
    FIELD="$1"
    FILE="$2"
    $JQ -Mr "$FIELD |length" "$FILE"
}

function run_curl () {
    # run curl with flags, return exit code
    # data is
    path="$1"
    results="$2"
    set +e
    h_code=$($CURL -Ssw '%{http_code}\n' "http://localhost:8000/$path" -o "$results")
    set -e
    echo "$h_code"
}

function check_code () {
    # test result codes, and send message about it
    msg="$1"
    want="$2"
    got="$3"
    if [[ "$want" != "$got" ]]; then
	err_log "$msg failed, $want != $got"
    fi
    log "$msg ok"
}

# start boshdns process
FASTLOG="/tmp/boshdns-runlog.txt"
debug_log "fastapi at $FASTAPI"
"$FASTAPI" dev --no-reload --port 8000 boshdns.py > "$FASTLOG" &
FAST_PID=$!
log "\nwating for startup..."
sleep 5
log "fastapi at $FAST_PID\n"

# make sure it is running
if [[ ! -d "/proc/$FAST_PID" ]]; then
    err_log "FastAPI startup failed (see $FASTLOG)?"
fi

# tests

# simple invalid path
logn "test invalid path: "
result=$(run_curl "foo" "results/badurl.json")
check_code "returns 404" "404" "$result"
msg=$(get_results ".detail" "results/badurl.json")
check_code "should be \"not found\"" "Not Found" "$msg"

# valid hostname
logn "test easy hostname "
result=$(run_curl "lookup/google.com" "results/google.json")
check_code "valid lookup" "200" "$result"
len=$(get_results_len ".addresses" "results/google.json")
are_gt "more than 0 addresses" 0 $len
