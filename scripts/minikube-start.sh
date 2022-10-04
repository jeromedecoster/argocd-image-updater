#!/bin/bash

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

info SCRIPT $0 $@

log START $(date "+%Y-%d-%m %H:%M:%S")
START=$SECONDS

# $ minikube status
# host: Stopped
# kubelet: Stopped
# apiserver: Stopped
# kubeconfig: Stopped
if [[ $(minikube status --format='{{.Host}}') != 'Running' ]]; then
    log START minikube
    minikube start --driver=docker
fi

# message stdout : empty || context-name
# message stderr : error: current-context is not set
context() {
    kubectl config current-context 2>/dev/null 
}

if [[ -z $(context) ]]; then
    log WAIT kubectl config current-context
    while [[ -z $(context) ]]; do sleep 1; done
fi

# kubernetes shortcuts
# po : Pods
# rs : ReplicaSets
# deploy : Deployments
# svc : Services
# ns : Namespaces
# netpol : Network policies
# pv : Persistent Volumes
# pvc : PersistentVolumeClaims
# sa : Service Accounts

namespaces() {
    kubectl get ns 2>/dev/null
}

if [[ -z $(namespaces) ]]; then
    log WAIT kubectl get namespace
    while [[ -z $(namespaces) ]]; do sleep 1; done
fi

log END $(date "+%Y-%d-%m %H:%M:%S")
info DURATION $(($SECONDS - $START)) seconds