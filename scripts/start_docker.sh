#! /usr/bin/env bash

IMAGE_NAME="croakexciting/rel4_dev"
IMAGE_VERSION="0.0.1"
CONTAINER_NAME="rel4_dev"
CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

function remove_container_if_exists() {
    local container="$1"
    if docker ps -a --format '{{.Names}}' | grep -q "${container}"; then
        echo "Removing existing ffos container: ${container}"
        docker stop "${container}" >/dev/null
        docker rm -v -f "${container}" 2>/dev/null
    fi
}

function show_usage() {
	    cat <<EOF
Usage: $0 [workspace_path]
EOF
}

function check_args() {
    if [ "$#" -eq 0 ]; then
        show_usage
        exit 0
    fi
}

function main() {
    check_args "$@"
    local workspace="$(realpath "$1")"
    remove_container_if_exists ${CONTAINER_NAME}
    
    local user="${USER}"
    local uid="$(id -u)"
    local group="$(id -g -n)"
    local gid="$(id -g)"

    docker run -itd \
        --name "${CONTAINER_NAME}" \
        -e DOCKER_USER="${user}" \
        -e DOCKER_USER_ID="${uid}" \
        -e DOCKER_GRP="${group}" \
        -e DOCKER_GRP_ID="${gid}" \
        -v $workspace:/workspace \
        -w /workspace \
        ${IMAGE_NAME}:${IMAGE_VERSION} \
        /bin/bash
    
    docker exec -u root ${CONTAINER_NAME} bash '/usr/local/bin/docker_start_user.sh'
}

main "$@"
