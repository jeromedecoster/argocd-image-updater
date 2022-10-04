#!/bin/bash

log() { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }          # $1 background white
info() { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }       # $1 background green
warn() { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; }  # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

# the directory containing the script file
export PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"

#
# variables
#
[[ -f $PROJECT_DIR/.env ]] \
    && source $PROJECT_DIR/.env \
    || warn WARN .env file is missing

#
# overwrite TF variables
#
export TF_VAR_project_name=$PROJECT_NAME
export TF_VAR_aws_region=$AWS_REGION
export TF_VAR_github_owner=$GITHUB_OWNER
export TF_VAR_github_repo=$GITHUB_REPO
export TF_VAR_docker_image=$DOCKER_ACCOUNT_ID/$APP_NAME
export TF_VAR_ecr_repo=$APP_NAME

# /!\ create a token here : https://github.com/settings/tokens
# /!\ must be checked : repo + admin:public_key

# https://unix.stackexchange.com/a/421111
# instead of source .env 2>/dev/null (get all variables from .env)
# define only GITHUB_TOKEN from .env
# eval "$(cat .env 2>/dev/null | grep ^GITHUB_TOKEN=)"
log GITHUB_TOKEN $GITHUB_TOKEN
export TF_VAR_github_token=$GITHUB_TOKEN

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

env-create() {
    # setup .env file with default values
    scripts/env-file.sh .env \
        AWS_PROFILE=default \
        PROJECT_NAME=argocd-image-updater \
        APP_NAME=app-version \
        APP_PORT=3000

    # setup .env file again
    # /!\ use your own values
    scripts/env-file.sh .env \
        AWS_REGION=eu-west-3 \
        GITHUB_OWNER=jeromedecoster \
        GITHUB_REPO=git@github.com:jeromedecoster/argocd-image-updater.git \
        DOCKER_ACCOUNT_ID=jeromedecoster \
        GITHUB_TOKEN=
}

terraform-create() {
    if [[ -z $(echo $GITHUB_TOKEN) ]]; then
        error ABORT GITHUB_TOKEN is not defined in .env file
        exit 0
    fi

    export CHDIR="$PROJECT_DIR/terraform"
    scripts/terraform-init.sh
    scripts/terraform-validate.sh
    scripts/terraform-apply.sh
}

# run app-version server using npm - dev mode
app-version() {
    cd "$PROJECT_DIR/$APP_NAME"
    npm install
    node index.js
}

# list docker images (filtered)
docker-images() {
    docker images \
        --filter="reference=$DOCKER_ACCOUNT_ID/$APP_NAME" \
        --filter="reference=$ECR_REPO_PUBLIC" \
        --filter="reference=$APP_NAME"
}

# build app-version image
prod-build() {
    log START $(date "+%Y-%d-%m %H:%M:%S")
    START=$SECONDS

    VERSION=$(jq '.version' --raw-output $APP_NAME/package.json)
    log VERSION $VERSION

    cd "$PROJECT_DIR/$APP_NAME"
    docker image build \
        --tag $APP_NAME \
        --tag $APP_NAME:$VERSION \
        .

    log END $(date "+%Y-%d-%m %H:%M:%S")
    info DURATION $(($SECONDS - $START)) seconds

    docker-images
}

# run app-version image
prod-run() {
    docker run \
        --rm \
        --env APP_PORT=$APP_PORT \
        --publish $APP_PORT:$APP_PORT \
        --name $APP_NAME \
        $APP_NAME
}

# stop app-version container
prod-stop() {
    docker rm --force $APP_NAME 2>/dev/null
}

minikube-create() {
    # start minikube
    scripts/minikube-start.sh

    # install argocd
    export TIMEOUT_RECONCILIATION=30s
    scripts/argocd-install.sh

    export CHECK_INTERVAL=30s
    scripts/argocd-image-updater-install.sh

    # kubectl create secret throw an error if secret already exists
    if [[ -z $(kubectl get secret git-creds -n argocd 2>/dev/null) ]]; then
        log CREATE secret git-creds
        # using token (connexion using https://github.com/xxx/xxx.git)
        # kubectl create secret generic git-creds \
        #   --from-literal=username=jeromedecoster \
        #   --from-literal=password=ghp_.... \
        #   --namespace argocd \

        ## using SSH (connexion using git@github.com:xxx/xxx.git)
        kubectl create secret generic git-creds \
            --from-file=sshPrivateKey=$PROJECT_DIR/$PROJECT_NAME.pem \
            --namespace argocd
    fi

    # kubectl get secret git-creds -o jsonpath='{.data.sshPrivateKey}' -n argocd | base64 --decode

    if [[ -z $(argocd repo get $GITHUB_REPO -o json 2>/dev/null) ]]; then
        log ADD repo $GITHUB_REPO
        argocd repo add $GITHUB_REPO \
            --insecure-ignore-host-key \
            --ssh-private-key-path $PROJECT_DIR/$PROJECT_NAME.pem
    fi
}

# push app-version image to docker
docker-push() {
    log START $(date "+%Y-%d-%m %H:%M:%S")
    START=$SECONDS

    cd "$PROJECT_DIR"
    VERSION=$(jq '.version' $APP_NAME/package.json --raw-output)
    log VERSION $VERSION
    
    TARGET_IMAGE=$DOCKER_ACCOUNT_ID/$APP_NAME
    log TARGET_IMAGE $TARGET_IMAGE

    # https://docs.docker.com/engine/reference/commandline/tag/
    docker tag $APP_NAME $TARGET_IMAGE:$VERSION
    docker tag $APP_NAME $TARGET_IMAGE:latest

    # https://docs.docker.com/engine/reference/commandline/push/
    docker push $TARGET_IMAGE:$VERSION
    docker push $TARGET_IMAGE:latest

    log END $(date "+%Y-%d-%m %H:%M:%S")
    info DURATION $(($SECONDS - $START)) seconds

    docker-images
}

ecr-private-push() {
    log START $(date "+%Y-%d-%m %H:%M:%S")
    START=$SECONDS

    cd "$PROJECT_DIR"
    VERSION=$(jq --raw-output '.version' $APP_NAME/package.json)
    log VERSION $VERSION

    source .env
    log AWS_ACCOUNT_ID $AWS_ACCOUNT_ID
    log ECR_REPO_PRIVATE $ECR_REPO_PRIVATE

    aws ecr get-login-password \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        | docker login \
        --username AWS \
        --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    # https://docs.docker.com/engine/reference/commandline/tag/
    docker tag $APP_NAME $ECR_REPO_PRIVATE:$VERSION
    docker tag $APP_NAME $ECR_REPO_PRIVATE:latest
    # https://docs.docker.com/engine/reference/commandline/push/
    docker push $ECR_REPO_PRIVATE:$VERSION
    docker push $ECR_REPO_PRIVATE:latest

    log END $(date "+%Y-%d-%m %H:%M:%S")
    info DURATION $(($SECONDS - $START)) seconds
}

ecr-public-push() {
    log START $(date "+%Y-%d-%m %H:%M:%S")
    START=$SECONDS

    cd "$PROJECT_DIR"
    VERSION=$(jq '.version' $APP_NAME/package.json --raw-output)
    log VERSION $VERSION

    # https://unix.stackexchange.com/a/421111
    # instead of source .env 2>/dev/null (get all variables from .env)
    # define only ECR_REPO_PUBLIC from .env
    # eval "$(cat .env 2>/dev/null | grep ^ECR_REPO_PUBLIC=)"
    # log ECR_REPO_PUBLIC $ECR_REPO_PUBLIC

    aws ecr-public get-login-password \
        --region us-east-1 \
        | docker login \
        --username AWS \
        --password-stdin $ECR_REPO_PUBLIC

    # https://docs.docker.com/engine/reference/commandline/tag/
    # log REPOSITORY_ECR_PUBLIC $REPOSITORY_ECR_PUBLIC
    docker tag $APP_NAME $ECR_REPO_PUBLIC:$VERSION
    docker tag $APP_NAME $ECR_REPO_PUBLIC:latest
    # https://docs.docker.com/engine/reference/commandline/push/
    docker push $ECR_REPO_PUBLIC:$VERSION
    docker push $ECR_REPO_PUBLIC:latest

    log END $(date "+%Y-%d-%m %H:%M:%S")
    info DURATION $(($SECONDS - $START)) seconds

    docker-images
}

secret-ecr-creds() {
    # used to pull image from private ECR by argocd-image-updater
    TOKEN=$(aws ecr get-login-password --region $AWS_REGION)
    kubectl create secret generic aws-ecr-creds \
        --from-literal=creds=AWS:$TOKEN \
        --dry-run=client \
        --namespace argocd \
        --output yaml \
        | kubectl apply --filename -

    kubectl create ns my-app 2>/dev/null

    # used to pull image from private ECR by the deployment manifest
    kubectl create secret docker-registry regcred -n my-app \
        --docker-server=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region $AWS_REGION)
}

# update-major-version() {
#     VERSION=$(jq --raw-output '.version' $APP_NAME/package.json)
#     log VERSION $VERSION

#     MAJOR=$(echo $VERSION | cut -d . -f 1)
#     MINOR=$(echo $VERSION | cut -d . -f 2)
#     PATCH=$(echo $VERSION | cut -d . -f 3)
#     # https://askubuntu.com/a/385532
#     # let:
#     # let "PATCH++"
#     # arithmetic expansion:
#     ((MAJOR++))
# }

# update-minor-version() {
#     VERSION=$(jq --raw-output '.version' $APP_NAME/package.json)
#     log VERSION $VERSION

#     MAJOR=$(echo $VERSION | cut -d . -f 1)
#     MINOR=$(echo $VERSION | cut -d . -f 2)
#     PATCH=$(echo $VERSION | cut -d . -f 3)

#     ((MINOR++))
# }

update-patch() {
    VERSION=$(jq --raw-output '.version' $APP_NAME/package.json)
    log VERSION $VERSION

    MAJOR=$(echo $VERSION | cut -d . -f 1)
    MINOR=$(echo $VERSION | cut -d . -f 2)
    PATCH=$(echo $VERSION | cut -d . -f 3)
    ((PATCH++))

    # https://stackoverflow.com/a/68136589
    # output redirection produces empty file with jq
    # needed to store in $UPDATED variable before write
    UPDATED=$(jq ".version = \"$MAJOR.$MINOR.$PATCH\"" $APP_NAME/package.json)
    echo "$UPDATED" > $APP_NAME/package.json

    info UPDATE $APP_NAME/package.json version to $(jq .version --raw-output $APP_NAME/package.json)
}

docker-watch() {
    local SVC_URL=$(minikube service \
        --url app-version \
        --namespace my-app)
    while true;
    do
        log TIME $(date +"%H:%M:%S")

        local LOCAL_VERSION=$(jq '.version' $PROJECT_DIR/$APP_NAME/package.json --raw-output)
        log LOCAL_VERSION $LOCAL_VERSION

        local NEWEST_DOCKER_TAG=$(curl "https://registry.hub.docker.com/v2/repositories/$DOCKER_ACCOUNT_ID/$APP_NAME/tags" \
            --location \
            --silent \
            | jq '."results"[]["name"]' \
            --raw-output \
            | grep latest \
            --invert-match \
            | head --lines 1)
        log NEWEST_DOCKER_TAG $NEWEST_DOCKER_TAG

        local GITHUB_SHA=$(curl "https://api.github.com/repos/$GITHUB_OWNER/$PROJECT_NAME/commits/master" \
            --header "Authorization: token $GITHUB_TOKEN" \
            --silent \
            | jq '.sha' \
            --raw-output)
        log GITHUB_SHA $GITHUB_SHA

        local ARGOCD_SYNC=$(argocd app get argocd-app \
            --output json \
            | jq '.status.sync.revision' \
            --raw-output)
        log ARGOCD_SYNC $ARGOCD_SYNC

        log "CURL $SVC_URL" $(curl $SVC_URL --silent)

        sleep 15
        echo
    done
}

image-updater-logs() {
    kubectl logs --selector app.kubernetes.io/name=argocd-image-updater \
        --namespace argocd \
        --follow
}

terraform-destroy() {
    terraform -chdir=$PROJECT_DIR/terraform destroy -auto-approve
}

# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info EXECUTE $1; eval $1; } || usage
exit 0
