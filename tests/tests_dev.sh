#!/bin/bash
set -eou pipefail
#
# Tests for development environment -- assume that this is running on a local
# machine (and thus BOSH isnt available, just the regular DNS lookup).

URL_BASE="http://localhost:8000"
if [ "${URL_BASE: -1}" == "/" ]; then
    # we need to remove trailing "/"
    URL_BASE=${URL_BASE:0:-1}
fi

# load common definitions
if [[ ! -f $(dirname "$0")/common.sh ]]; then
    echo "cannot find common.sh"
    exit 1
fi
source $(dirname "$0")/common.sh

# ensure a local copy of boshdns is runnable
set +e
FASTAPI=$(type -p fastapi)
[[ -z "$FASTAPI" ]] && echo "Expect to find 'fastapi' available" && exit 1
set -e

# we'll need to track the PID to ensure we can shut it down again
FAST_PID=''

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
