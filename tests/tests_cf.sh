#!/bin/bash
#
set -eou pipefail
#
# Tests against running instance in a CF.  Assume standard deploymens
# are available for lookup.

set +u
if [[ -z "$URL_BASE" ]]; then
    echo "Please set URL_BASE to point to the boshdns deployment"
    exit 1
fi
set -u
if [ "${URL_BASE: -1}" == "/" ]; then
    # we need to remove trailing "/"
    URL_BASE=${URL_BASE:0:-1}
fi

if [[ ! -f $(dirname "$0")/common.sh ]]; then
    echo "cannot find common.sh"
    exit 1
fi
source $(dirname "$0")/common.sh

# simple invalid path
logn "test invalid path: "
result=$(run_curl "foo" "results/badurl.json")
check_code "returns 404" "404" "$result"
msg=$(get_results ".detail" "results/badurl.json")
check_code "should be \"not found\"" "Not Found" "$msg"

# simple deployment name
logn "check diego-cells "
result=$(run_curl "lookup/diego-cell", "results/diego-cell.json")
check_code "returns 200" "200" "$result"
len=$(get_results_len ".addresses" "results/diego-cell.json")
are_gt "more than 0 addresses" 0 $len
