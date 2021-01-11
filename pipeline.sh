#!/bin/bash

syntax="
Syntax:
    magic.sh Command [EnvType] [Options]

    EnvType: (local) staging production

    Command:
        build local|staging|production
            - builds image
            - runs it
            - tests with curl

        deploy staging|production
            - builds image
            - runs it
            - tests with curl
            - deploys to AWS
            - tests with curl
        
        test staging|production
            - tests url
"

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#  H E L P E R S
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Color helper functions
red()    { echo -e "\n${RED}$1${RESET}"    ; }
blue()   { echo -e   "${BLUE}$1${RESET}"   ; }
green()  { echo -e   "${GREEN}$1${RESET}"  ; }
purple() { echo -e "\n${PURPLE}$1${RESET}" ; }
yellow() { echo -e   "${YELLOW}$1${RESET}" ; }

# - - - - - - -

🌷() {
    echo -en ${YELLOW}
    printf '🌷 %s\n' "$*"  # >&2 makes pipes work, even tho' they don't print properly
    echo -en ${RESET}
    "$@"
}

# - - - - - - -

assert_exists () {
    if hash $1 2>/dev/null; then
        green "$1 exists"
    else
        red "Fatal Error: $1 does not exist" >&2
        exit 1
    fi
}

check_cli_tools() {
    purple "Checking CLI tools"

    assert_exists docker
    assert_exists aws
    # assert_exists eksctl
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# change to script's containing folder, and store it
cd `dirname "$0"`
SCRIPT_ROOT=`pwd -P`

all_args="$@"

cmd=$1
env_type=${2:-local}  # (local) | staging | production

AWS_ECR_REPO_NAME="lambdabash-${env_type}"
AWS_LAMBDAFUNC_NAME="lambdabash-${env_type}"
LAMBDA_MEMORY_MB=1024
LAMBDA_TIMEOUT_S=30
DOCKER_IMAGE_TAG="lambdabash-${env_type}"
DOCKER_RUNNING_CONTAINER_NAME="lambdabash-${env_type}"

echo "🏹 AWS_ECR_REPO_NAME: $AWS_ECR_REPO_NAME"
echo "🏹 AWS_LAMBDAFUNC_NAME: $AWS_LAMBDAFUNC_NAME"
echo "🏹 DOCKER_IMAGE_TAG: $DOCKER_IMAGE_TAG"
echo "🏹 DOCKER_RUNNING_CONTAINER_NAME: $DOCKER_RUNNING_CONTAINER_NAME"

# TODO: Create role through CLI (currently fetching it from AWS)
role_arn="arn:aws:iam::795730031374:role/service-role/ls-lambda-role-ka10n7ab"

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#  S W I T C H B O A R D
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main() {
    # `set -v` (rather than -x) to echo commands
    # `set -e` to quit on error
    # `set -a` to store all defined vars in shell environment
    # (use + to OFF the flag)
    set -e

    if [ -z $cmd ] || [  $cmd = "help" ]; then
        green "$syntax"
        exit 0
    fi

    check_cli_tools

    if [ $cmd = "setup" ]; then
        setup

    elif [ $cmd = "build" ]; then
        build

    elif [ $cmd = "deploy" ]; then
        deploy

    elif [ $cmd = "test" ]; then
        test

    else
        red "Unknown command. 'pipeline.sh help' for available commands."
    fi
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# Just here for reference
setup_one_time() {
    aws ecr create-repository --repository-name $AWS_ECR_REPO_NAME
}

# - - - - - - -

# TODO: Use RIE for more accurate local testing
setup_one_time_per_devbox() {
    purple "One time!"

    mkdir -p ~/.aws-lambda-rie

    curl -Lo ~/.aws-lambda-rie/aws-lambda-rie \
        https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie

    chmod +x ~/.aws-lambda-rie/aws-lambda-rie
}

# - - - - - - -

setup() {
    echo "Empty"
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

build() {
    cd src

    purple "Building Docker image"
    🌷 docker build -t $DOCKER_IMAGE_TAG .
    # 🌷 docker build -t $DOCKER_IMAGE_TAG --no-cache .

    purple "remove if running container exists (safe to ignore error, it means local container not found)"
    docker container inspect $DOCKER_RUNNING_CONTAINER_NAME 2>&1 >/dev/null \
        && 🌷 docker rm -f $DOCKER_RUNNING_CONTAINER_NAME
    # ^ We do this in case a previous build failed to complete, leaving a dangling running container

    purple "Running Docker image in daemon mode"
    🌷 docker run -d \
        --name $DOCKER_RUNNING_CONTAINER_NAME \
        -p 9000:8080 \
        $DOCKER_RUNNING_CONTAINER_NAME:latest

    purple "Give it some time to warm up"
    🌷 sleep 5

    purple "Testing endpoint"
    🌷 curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
        -d "test"

    while true;
    do
        purple "`cat << EOF
            l      to inspect log
            v      to view generated file
            s      to ssh into box first (use CTRL+d to quit shell).
            q      to delete local Docker container instance and quit.
            CTRL+c to quit without deleting container instance

            Hit a key...
EOF
`"
        read -rsn1 keystroke

        if [ "$keystroke" = "v" ]; then
            purple "Viewing /tmp/generated-file.txt"
            🌷 docker cp $DOCKER_IMAGE_TAG:/tmp/generated-file.txt /tmp/generated-file.txt
            🌷 cat /tmp/generated-file.txt

        elif [ "$keystroke" = "l" ]; then
            purple "Fetching log"
            🌷 docker logs $DOCKER_IMAGE_TAG

        elif [ "$keystroke" = "s" ]; then
            purple "Launching shell"
            🌷 docker exec -it $DOCKER_IMAGE_TAG /bin/sh

        elif [ "$keystroke" = "q" ]; then
            break
        fi
    done

    purple "Destroy running container"
    🌷 docker rm -f $DOCKER_RUNNING_CONTAINER_NAME
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

deploy() {
    # If repo doesn't exist, create it
    purple "Checking if repo exists on AWS ECR (ignore error)"
    if aws ecr describe-repositories --repository-names ${AWS_ECR_REPO_NAME} 2>&1 >/dev/null ; then
        green "Found AWS ECR repo: ${AWS_ECR_REPO_NAME}"
    else
        purple "AWS ECR repo (${AWS_ECR_REPO_NAME}) not found, creating!"
        🌷 aws ecr create-repository --repository-name ${AWS_ECR_REPO_NAME}
    fi

    # Note:
    #   .repositoryArn gives e.g. arn:aws:ecr:us-east-1:795730031374:repository/foo, so we strip the /foo for lambda_uri
    purple "Extracting URI for repo"
    repo_info=$( aws ecr describe-repositories --repository-names $AWS_ECR_REPO_NAME | jq -r '.repositories[0]' )
    lambda_uri=$( echo "$repo_info" | jq -r '.repositoryUri | split("/")[0]' )
    echo -e "${GREEN}Lambda URI: ${YELLOW}$lambda_uri"  # e.g. 795730031374.dkr.ecr.us-east-1.amazonaws.com

    # Can't mix 🌷 with pipes, so we print the command manually
    purple "Logging into AWS ECR Docker repository"
    yellow "🌷 aws ecr get-login-password | docker login --username AWS --password-stdin $lambda_uri"
    aws ecr get-login-password | \
        docker login \
            --username AWS \
            --password-stdin \
            $lambda_uri

    full_url=$lambda_uri/${AWS_ECR_REPO_NAME}:latest
    red "Lambda URL: $lambda_uri/${AWS_ECR_REPO_NAME}:latest"

    # docker tag SOURCE_IMAGE[:TAG] TARGET_IMAGE[:TAG]
    purple "Tagging Docker image"
    🌷 docker tag $DOCKER_IMAGE_TAG:latest \
        ${lambda_uri}/${AWS_ECR_REPO_NAME}:latest

    purple "Pushing Docker image"
    🌷 docker push $full_url

    purple "If there is a running lambda function with this name, delete it. "
    🌷 aws lambda delete-function  \
        --function-name $AWS_LAMBDAFUNC_NAME \
        2>&1 >/dev/null \
        && :  # suppress exit-on-error

    purple "Create lambda function"
    🌷 aws lambda create-function  \
        --function-name $AWS_LAMBDAFUNC_NAME \
        --role $role_arn \
        --code ImageUri=$full_url \
        --package-type Image \
        --memory-size $LAMBDA_MEMORY_MB \
        --timeout $LAMBDA_TIMEOUT_S \
        --publish \
        | cat  # avoid requiring user interaction for multipage output

    # TODO: 
    #     Validate it uploaded ok
    #         aws lambda get-function --function-name lambdabash-staging

    test
}

test() {
    purple "Repeatedly test against endpoint"

    nTries=30
    response_file="response.json"

    for (( i=1; i<=$nTries; i++ )); do
        # test against remote endpoint
        aws lambda invoke \
            --function-name $AWS_LAMBDAFUNC_NAME \
            --cli-binary-format raw-in-base64-out \
            --payload '{ "message" : "Hello from Container Lambda" }' \
            $response_file \
            >/dev/null 2>&1 \
            && :

        if [ ! -f $response_file ]; then
            echo -en "${RED}x${RESET}"
            # sleep 1s
            continue
        fi

        response="$(cat $response_file)"

        echo "✅"

        # pretty print response if json, plain print otherwise
        #     https://stackoverflow.com/questions/46954692/check-if-string-is-a-valid-json-with-jq
        if jq --exit-status type >/dev/null 2>&1 <<<"$response"; then
            # Parsed JSON successfully and got something other than false/null
            green "Got JSON server response:"
            echo "$response" | jq .
            echo "... after $i seconds"
        else
            yellow "Response (not valid JSON):"
            echo -e "${BLUE}$response${BLUE}"
        fi
        break
    done

    if [ -f $response_file ]; then
        rm $response_file
    else
        red "No response. . Press ENTER to continue (or CTRL+c to abort)."
        head -n 1 >/dev/null
    fi
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main "$@"
