#!/bin/bash

set -eEuo pipefail

################################################################################
# TRAPS
################################################################################
trap "Error occurred! Have you called dev/init.sh beforehand?" ERR

finish() {
    read -r -n 1 -p "Waiting..."
    _cleanup || true
    _docker stop
}
trap finish EXIT

################################################################################
# VARIABLES
################################################################################
# TAXI
TAXI_ENV="local"
AGENCY="agency3"

# MISC
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
# AWS
################################################################################
export AWS_CONFIG_FILE="$HOME/.taxi/aws/config"
AWS_DEFAULT_OUTPUT="json"
_aws() {
    aws --endpoint-url "$AWS_ENDPOINT_URL" \
        --profile "$AWS_DEFAULT_PROFILE" \
        --output "$AWS_DEFAULT_OUTPUT" \
        $@
}

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

_prepare() {
    echo -e "${BBLU}[MISC]${BLU} prepare services${RST}"
    rm -rf "dev/sftp-data/$AGENCY"/* || true
}

_configure() {
    echo -e "${BBLU}[CONFIG]${BLU} using .env.local${RST}"
    source .env.local

    AWS_DEFAULT_PROFILE="taxi-minio-test"
    AWS_DEFAULT_BUCKET="testing"
    ROOT_AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    ROOT_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"

    TAXI_CACHE="/tmp/taxi-cache"
    rm -rf "$TAXI_CACHE"
    export TAXI_CACHE
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
    aws configure --profile "$AWS_DEFAULT_PROFILE" < "$tmpfile" > /dev/null
}

_aws_assume_role() {
    echo -e "${BYLW}[AWS]${YLW} Assume Role${RST}"
    aws --profile "$AWS_DEFAULT_PROFILE" configure set default.s3.signature_version s3v4
    tmpfile=$(mktemp)
    _aws sts assume-role --role-arn "$AWS_ROLE_TO_ASSUME" --role-session-name testing \
         > "$tmpfile"

    export AWS_ACCESS_KEY_ID=$(jq .Credentials.AccessKeyId "$tmpfile")
    export AWS_SECRET_ACCESS_KEY=$(jq .Credentials.SecretAccessKey "$tmpfile")
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
        _aws s3 mb "s3://$AWS_DEFAULT_BUCKET" || true
    fi

    subdir="$(basename $URL)"

    _aws s3 cp "$SAMPLE_DIR" "s3://$AWS_DEFAULT_BUCKET/$subdir" --recursive > /dev/null
    _success
}

_taxi_tests() {
    echo -e "${BBLU}[TAXI]${BLU} Staring test run...${RST}"

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    export AWS_ACCESS_KEY_ID="$ROOT_AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$ROOT_AWS_SECRET_ACCESS_KEY"

    NAME="template"
    BUCKET="testing"
    LANG_FROM="en_US"
    LANG_TO="de_DE"
    echo -e "${BBLU}[TAXI] {package}${BLU} make${RST}"
    bundle exec ./bin/taxi package make "$NAME" "$(basename $SAMPLE_DIR)" --bucket="$BUCKET"
    _success

    echo -e "${BBLU}[TAXI] {package}${BLU} translate${RST}"
    bundle exec ./bin/taxi package translate "$NAME" "$LANG_FROM" "$LANG_TO" --agency="$AGENCY" --bucket="$BUCKET"
    _success

    echo -e "${BBLU}[TAXI] {SFTP}${BLU} mv${RST}"
    bundle exec ./bin/taxi sftp mv "template-$LANG_FROM-$LANG_TO" --agency="$AGENCY"
    _success

    echo -e "${BBLU}[TAXI] {package}${BLU} deploy${RST}"
    bundle exec ./bin/taxi package deploy "$NAME" "$(basename $SAMPLE_DIR)" "$LANG_TO" --agency="$AGENCY" --bucket="$BUCKET"
    _success

    # final check
    DOWNLOAD_DIR="/tmp/taxi-translated"
    rm -rf "$DOWNLOAD_DIR"
    subdir="$(basename $URL)"

    echo -e "${BBLU}[TAXI] Check original and final files${RST}"
    _aws s3 cp "s3://$AWS_DEFAULT_BUCKET/$subdir/" "$DOWNLOAD_DIR" --recursive >/dev/null
    if diff -q -r "$SAMPLE_DIR" "$DOWNLOAD_DIR/${LANG_TO::2}/"; then
        _success
    else
        _fail
    fi
}

_cleanup() {
    echo -e "${BYLW}[S3]${YLW} Cleanup${RST}"
    _aws s3 rb "s3://$AWS_DEFAULT_BUCKET" --force > /dev/null
    _success
}

################################################################################
# MAIN
################################################################################
_run() {
    # download sample HTML
    _download_sample
    # start docker containers
    _docker start
    # wait until services are running
    sleep 3
    # prepare SFTP and S3
    _prepare
    # configure environment and AWS CLI
    _configure
    _aws_configure
    _aws_assume_role
    # upload the sample HTML to S3
    _upload_sample
    # run tests
    _taxi_tests
    # EXIT trap calls _cleanup
    # EXIT trap stops containers
}

_main() {
    local CMD="$1"
    shift
    case "$CMD" in
        docker)
            _docker "$@"
            ;;
        ci)
            ./dev/init.sh
            _run
            ;;
        test)
            _run
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
