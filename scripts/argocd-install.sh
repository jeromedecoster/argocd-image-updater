#!/bin/bash

# usage:
# TIMEOUT_RECONCILIATION=<delay> argocd-install.sh
#
# delay:
#   3m | 2m10s | 1m | 30s 

# https://github.com/ishitasequeira/argo-cd/blob/b329e4d91c00d48d1dd2dea3d5002b381603a899/manifests/install.yaml#L10245-L10256
# env var `ARGOCD_RECONCILIATION_TIMEOUT` taken from key `timeout.reconciliation` within ConfigMap `argocd-cm`

# https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.0-2.1/#replacing-app-resync-flag-with-timeoutreconciliation-setting
# default argocd value : timeout.reconciliation: 180s

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

info SCRIPT $0

[[ -z $(printenv | grep ^TIMEOUT_RECONCILIATION=) ]] \
    && { error ABORT TIMEOUT_RECONCILIATION env variable is required; exit 1; } \
    || log TIMEOUT_RECONCILIATION $TIMEOUT_RECONCILIATION

log START $(date "+%Y-%d-%m %H:%M:%S")
START=$SECONDS

# check if the namespace argocd exists
argocd-ns() {
    kubectl get ns argocd 2>/dev/null
}

if [[ -z $(argocd-ns) ]]; then
    log CREATE namespace argocd
    kubectl create ns argocd 2>/dev/null
fi

# check if the service argocd-applicationset-controller is defined
# in the argocd namespace. This is the first thing available when
# argocd is installed
argocd-svc() {
    kubectl get svc argocd-applicationset-controller -n argocd 2>/dev/null
}

if [[ -z $(argocd-svc) ]]; then
    # direct install
    # kubectl apply \
    #     --namespace argocd \
    #     --filename https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    TEMP_DIR=$(mktemp --directory /tmp/argocd-XXXX)
    info TEMP_DIR $TEMP_DIR

    curl https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
        --output $TEMP_DIR/install.yaml \
        --silent

    cat >$TEMP_DIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- install.yaml

patches:
- target:
    kind: ConfigMap
    name: argocd-cm
  patch: |-
    - op: add
      path: /data
      value:
        timeout.reconciliation: $TIMEOUT_RECONCILIATION
EOF

    log KUSTOMIZE $TEMP_DIR/kustomization.yaml
    cat $TEMP_DIR/kustomization.yaml

    kustomize build $TEMP_DIR \
    | kubectl apply \
        --namespace argocd \
        --filename -
fi

# by default : ClusterIP
# if patched : LoadBalancer
argocd-server-lb() {
    kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.type}' 2>/dev/null
}

if [[ $(argocd-server-lb) != 'LoadBalancer' ]]; then
    log WAIT argocd-server
    kubectl wait deploy argocd-server \
        --timeout=180s \
        --namespace argocd \
        --for=condition=Available=True

    log CREATE load balancer
    kubectl patch svc argocd-server \
        --namespace argocd \
        --patch '{"spec": {"type": "LoadBalancer"}}'
fi

SERVICE_URL=$(minikube service --url argocd-server --namespace argocd 2>/dev/null | tail --lines 1)
log SERVICE_URL $SERVICE_URL

SERVICE_IP=$(echo $SERVICE_URL | cut -d : -f 2 | sed 's|/||g')

# https://linuxhint.com/edit-etc-hosts-linux/
# https://sslhow.com/understanding-etc-hosts-file-in-linux
if [[ -z $(grep --color=none "$SERVICE_IP\s*minikube" /etc/hosts) ]]; then
    error ABORT inject the line \"$SERVICE_IP minikube\" into the /etc/hosts file
    exit 0
fi

LB_PORT=$(echo "$SERVICE_URL" | cut -d : -f 3)
log LB_PORT $LB_PORT

ARGO_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
    --namespace argocd \
    --output jsonpath="{.data.password}" |
    base64 --decode)

info OPEN "https://minikube:$LB_PORT"
warn ACCEPT insecure self-signed certificate
info LOGIN admin
info PASSWORD $ARGO_PASSWORD

log LOGIN argocd
argocd login minikube:$LB_PORT \
    --insecure \
    --username=admin \
    --password=$ARGO_PASSWORD

log END $(date "+%Y-%d-%m %H:%M:%S")
info DURATION $(($SECONDS - $START)) seconds