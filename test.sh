#!/bin/bash

set -eEuo pipefail

################################################################################
# TRAPS
################################################################################
trap "Error occurred! Have you called dev/init.sh beforehand?" ERR

finish() {
    _cleanup
    _docker stop
}
trap finish EXIT

################################################################################
# VARIABLES
################################################################################
TAXI_ENV="local"
TAXI_CACHE="$(mktemp -d -t taxi-cache.XXXXXX)"

TMPDIR="/tmp"
URL="http://techdoc-staging-2461a59e0ce82aa4080ef3bd0eee14f1.s3-website.eu-central-1.amazonaws.com/docs-template/"
SAMPLE_DIR="${TMPDIR}/${URL#http://}"

# COLORS
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
BRED='\033[1;31m'
BGRN='\033[1;32m'
BYLW='\033[1;33m'
BBLU='\033[1;34m'
RST='\033[0m'

################################################################################
# FUNCTIONS
################################################################################
_success() {
    echo -e "    ${BGRN}SUCCESS${RST}"
}

_fail() {
    echo -e "    ${BRED}FAIL${RST}"
    exit 1
}

_download_sample() {
    rm -rf "$SAMPLE_DIR"
    pushd "$TMPDIR" > /dev/null
    echo -e "${BBLU}[SETUP] ${BLU}Downloading sample:${RST} ${URL}"
    if ! wget --recursive \
         --no-clobber \
         --page-requisites \
         --html-extension \
         --convert-links \
         --domains techdoc-staging-2461a59e0ce82aa4080ef3bd0eee14f1.s3-website.eu-central-1.amazonaws.com \
         --no-parent \
         "$URL" > "taxi-wget-$(date +%Y-%m-%d).log" 2>&1
    then
        _success
    else
        _fail
    fi
    popd > /dev/null
}

_configure() {
    echo -e "${BBLU}[CONFIG]${BLU} using .env.local${RST}"
    source .env.local

    AWS_PROFILE="taxi-minio-test"

    AWS_DEFAULT_BUCKET="testing"
    AWS_DEFAULT_OUTPUT="json"

    ROOT_AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    ROOT_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
}

_aws_configure() {
    echo -e "${BYLW}[CONFIG]${YLW} AWS CLI${RST}"
    local tmpfile="$(mktemp)"
    (
        echo "$AWS_ACCESS_KEY_ID"
        echo "$AWS_SECRET_ACCESS_KEY"
        echo "$AWS_DEFAULT_REGION"
        echo "json"
    ) >> "$tmpfile"
    aws configure --profile "$AWS_PROFILE" < "$tmpfile" > /dev/null
}

_aws_assume_role() {
    echo -e "${BYLW}[AWS]${YLW} Assume Role${RST}"
    aws --profile "$AWS_PROFILE" configure set default.s3.signature_version s3v4
    tmpfile=$(mktemp)
    aws --endpoint-url "$AWS_ENDPOINT_URL" \
        --profile "$AWS_PROFILE" \
        sts assume-role --role-arn "$AWS_ROLE_TO_ASSUME" --role-session-name testing \
        > "$tmpfile"

    AWS_ACCESS_KEY_ID=$(jq .Credentials.AccessKeyId "$tmpfile")
    AWS_SECRET_ACCESS_KEY=$(jq .Credentials.SecretAccessKey "$tmpfile")
}

_docker() {
    local DOCKER_COMPOSE="dev/docker-compose.yml"
    local FLAGS="--remove-orphans"
    echo -e "${BBLU}[DOCKER]${BLU} ${1}${RST}"
    case "$1" in
        start | up)
            docker-compose -f "$DOCKER_COMPOSE" up $FLAGS --force-recreate -d
            ;;
        stop | down)
            docker-compose -f "$DOCKER_COMPOSE" down $FLAGS
            ;;
        *)
            echo "_docker: '$1' not a valid option"
            exit 1
            ;;
    esac
}

_upload_sample() {
    echo -e "${BYLW}[S3]${YLW} Upload${RST}"

    if [[ "$TAXI_ENV" == "local" ]]; then
        aws --endpoint-url "$AWS_ENDPOINT_URL" \
            --profile "$AWS_PROFILE" \
            s3 mb "s3://$AWS_DEFAULT_BUCKET" || true
    fi

    subdir="$(basename $URL)"

    aws --endpoint-url "$AWS_ENDPOINT_URL" \
        --profile "$AWS_PROFILE" \
        s3 cp "$SAMPLE_DIR" "s3://$AWS_DEFAULT_BUCKET/$subdir" --recursive > /dev/null
    _success
}

_taxi_tests() {
    export TAXI_ENV
    export TAXI_CACHE

    AWS_ACCESS_KEY_ID="$ROOT_AWS_ACCESS_KEY_ID"
    AWS_SECRET_ACCESS_KEY="$ROOT_AWS_SECRET_ACCESS_KEY"

    taxi="bundle exec ./bin/taxi"
    $taxi package make testing "$(basename $SAMPLE_DIR)"
}

_cleanup() {
    echo -e "${BYLW}[S3]${YLW} Cleanup${RST}"
    aws --endpoint-url "$AWS_ENDPOINT_URL" \
        --profile "$AWS_PROFILE" \
        s3 rb "s3://$AWS_DEFAULT_BUCKET" --force > /dev/null
    _success
}

################################################################################
# MAIN
################################################################################
_main() {
    local CMD="$1"
    shift
    case "$CMD" in
        docker)
            _docker "$@"
            ;;
        test)
            # download sample HTML
            _download_sample
            # start docker containers
            _docker start
            # configure environment and AWS CLI
            _configure
            _aws_configure
            _aws_assume_role
            # upload the sample HTML to S3
            _upload_sample
            read -n 1 -p "Press Enter"
            # run tests
            _taxi_tests
            # EXIT trap calls _cleanup
            # EXIT trap stops containers
            ;;
        *)
            echo "Undefined command: $CMD"
            ;;
    esac
}

################################################################################
# ENTRY
################################################################################
if [[ "$#" == 0 ]]; then
    cat <<EOS
Usage: $0 COMMAND

Available commands:
    docker start|up|stop|down     start or stop local docker infrastructure
    test                          runs test script on local docker infrastructure
EOS
else
    _main "$@"
fi
