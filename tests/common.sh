# ensure we're in the right place
[[ ! -d tests ]] && echo "Please run from the root repo" && exit 1
[[ ! -f boshdns.py ]] && echo "Please run from the root repo" && exit 1
[[ ! -d results ]] && mkdir results

# support applications needed
CURL=$(type -p curl)
set +e
[[ -z "$CURL" ]] && echo "Need curl to run tests" && exit 1
set -e
JQ=$(type -p jq)
set +e
[[ -z "$JQ" ]] && echo "Need jq to run tests" && exit 1
set -e

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

if [[ "$URL_BASE" = "" ]]; then
       echo "Set URL_BASE"
       return
fi

function run_curl () {
    # run curl with flags, return exit code
    # data is
    path="$1"
    results="$2"
    set +e
    h_code=$($CURL -Ssw '%{http_code}\n' "$URL_BASE/$path" -o "$results")
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
