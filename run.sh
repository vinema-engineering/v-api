# Check first for running containers
# If they don't exist, run docker-compose up -d

#Edit the following

#!/usr/bin/env bash
IMAGE_NAME=invent_server
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOC_ROOT="$( dirname "${DIR}")"
WEB_PORT=3000

# Helper Methods
function getImageStatus(){
    echo ">>>>>> Checking image ${IMAGE_NAME} status"
    RESPONSE=$(docker image inspect --format='{{.RepoTags}}' ${IMAGE_NAME})
    if [[ ${RESPONSE} == "[${IMAGE_NAME}:latest]" ]] ; then
        echo "Image ${IMAGE_NAME} already built <<<<<<"
        return 0
    else
        echo "Image ${IMAGE_NAME} not built <<<<<<"
        return 1
    fi
}

function getContainerStatus(){
    echo ">>>>>> Checking container status"
    CONTAINER_ID=$(docker ps -a | grep -v Exit | grep ${IMAGE_NAME} | awk '{print $1}')
    if [[ -z ${CONTAINER_ID} ]] ; then
        echo "Container ${CONTAINER_ID} not running <<<<<<"
        return 1
    else
        echo "Running in container: ${CONTAINER_ID} <<<<<<"
        return 0
    fi
}

function getExitedContainerStatus(){
    echo ">>>>>> Checking Exited container status"
    CONTAINER_ID=$(docker ps -a | grep Exit | grep ${IMAGE_NAME} | awk '{print $1}')
    if [[ -z ${CONTAINER_ID} ]] ; then
        echo "No Exited container found <<<<<<"
        return 1
    else
        echo "Exited container: ${CONTAINER_ID} <<<<<<"
        return 0
    fi
}

function buildImage() {
    if [[ $? == 1 ]] ; then
        echo ">>>>>> Starting image ${IMAGE_NAME} build"
        # To build the project for the first time or when you add dependencies
        docker build -t ${IMAGE_NAME} ${DOC_ROOT}
        echo "Image ${IMAGE_NAME} build COMPLETE <<<<<<"
    fi
}

function removeContainer() {
    # Clean up any running container
    echo ">>>>>> Starting container Clean up"
    if [[ -z $1 ]] ; then
        echo "No Container, nothing to clean <<<<<<"
    else
        SRV=$(docker stop $1)
        SRV=$(docker rm $1)
        echo "Container $1 clean up complete <<<<<<"
    fi
}

function runContainerInBackground() {
    echo '>>>>>> Starting background process'

    docker run \
        -d \
        --name ${IMAGE_NAME} \
        -p ${WEB_PORT}:${WEB_PORT} \
        -v ${DOC_ROOT}:/invent_server \
        -e NODE_ENV=production \
        --network=inventone_network \
        ${IMAGE_NAME} \
        sh -c "npm i -g forever && npm i && npm run docs && npm run prod:server"

    echo 'Running in background <<<<<<'
}

function showHelp() {
    echo "Software Help:"
    echo "----"
    echo "-a   : Attach to a running container"
    echo "-b   : Attempt to build Image and start containers (docker compose up)"
    echo "-d   : Run container in daemon mode (background)"
    echo "-i   : Run container in interactive mode"
    echo "-r   : Restart container"
    echo "-rm  : Remove container"
    echo "    -r [name/id]  : Restart container with name or id"
    echo "-s"
    echo "    -s [name/id]  : Start container with name or id"
    echo "-sp"
    echo "    -sp [name/id] : Stop container with name or id"
}
# Confirm that the external network "inventone_network" exists otherwise create it
{
    echo ">>>>> Checking if 'inventone_network' exists ..."
    docker network ls | grep " inventone_network "
} || {
    echo "-----> Network does not exist, creating 'inventone_network' now ..."
    docker network create inventone_network
}

echo "Initial system setup (network) complete <<<<<<"

getImageStatus
buildImage

# -e DOCKER_MONGODB_URI=mongodb://mongo:27017/invent_server \ -- Change to MySQL
if [[ $1 == "-b" ]] ; then
    getImageStatus
    buildImage
    # docker-compose build web
    echo ">>>>>> Start containers (docker compose up)"
    docker-compose -p invent_server up -d
    echo "Containers Started (docker compose up) <<<<<<"

elif [[ $1 == "-d" ]] ; then
    runContainerInBackground

elif [[ $1 == "-r" ]] ; then
    if [[ -z $2 ]] ; then
        CONTAINER_ID=$(docker ps -a | grep -v Exit | grep ${IMAGE_NAME} | awk '{print $1}')
        if [[ -z ${CONTAINER_ID} ]] ; then
            echo ">>>>>> No container exists, starting . . ."

            removeContainer "$CONTAINER_ID"

            cd ${DOC_ROOT}

            source ${DIR}/start.sh -d

            echo "Container started in background! <<<<<<"
        fi
    else
        removeContainer "$2"
    fi
elif [[ $1 == "-rm" ]]; then
    echo ">>>>>> Remove container . . ."
    if [[ $2 ]] ; then
        removeContainer "$2"
        echo "Container $2 removed successfully <<<<<<"
    else
        echo "Please add container name to remove <<<<<<"
    fi
elif [[ $1 == "-a" ]] ; then
    echo ">>>>>> Starting container attachment checks . . ."
    if [[ -z $2 ]] ; then
        CONTAINER_ID=$(docker ps -a | grep -v Exit | grep ${IMAGE_NAME} | awk '{print $1}')

        if [[ -z ${CONTAINER_ID} ]] ; then
            echo "Attachment failed: container does not exist <<<<<<"
        else
            echo "-----> Attaching to Container: ${CONTAINER_ID}"
            docker exec -it ${CONTAINER_ID} bash
            echo "End of container attachment process: ${CONTAINER_ID} <<<<<<"
        fi
    else
        echo "-----> Attaching to Container: $2"
        docker exec -it $2 bash
        echo "End of container attachment process: $2 <<<<<<"
    fi
elif [[ $1 == "-s" ]] ; then
    echo ">>>>>> Starting container (docker start) . . ."
    if [[ $2 ]] ; then
        docker start $2
        echo ">>>>>> Container started (docker start) . . ."
    else
        echo ">>>>>> No container to start (docker stop) . . ."
    fi
elif [[ $1 == "-sp" ]] ; then
    echo ">>>>>> Stopping container (docker stop) . . ."
    if [[ $2 ]] ; then
        docker stop $2
        echo ">>>>>> Container stopped (docker stop) . . ."
    else
        echo ">>>>>> No container to stop (docker stop) . . ."
    fi
elif [[ $1 == "-i" ]] ; then
    echo ">>>>>> Starting container in interactive mode"
    docker run \
        -i -t \
        --name ${IMAGE_NAME} \
        -p ${WEB_PORT}:${WEB_PORT} \
        -v ${DOC_ROOT}:/invent_server \
        -e NODE_ENV=production \
        --network=inventone_network \
        ${IMAGE_NAME} \
        sh -c "npm i && npm run build && npm run docs && bash"

    echo "Exited Container <<<<<<"

    # Clean up after exit
    echo ">>>>>> Cleaning up after exit"
    getExitedContainerStatus
    if [[ $? == 0 ]] ; then
        SRV=$(docker stop ${CONTAINER_ID})
        SRV=$(docker rm ${CONTAINER_ID})
        echo "Container ${CONTAINER_ID} stopped and removed <<<<<<"
    else
        echo "No Container, nothing to clean <<<<<<"
        exit 1
    fi
elif [[ $1 == "-h" ]] ; then
    showHelp
else
    showHelp
fi
