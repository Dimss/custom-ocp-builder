#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

echo "---> Starting custom build . . ."
SRC_DIR=$(pwd)/src
OCP_DIR=${SRC_DIR}/ocp
CONFIG_SECRET_NAME=builder-config
TEMPLATE_NAME=ci-s2i-custom-template.yaml
MASTER_URL=$(</tmp/${CONFIG_SECRET_NAME}/master_url)
OCP_USER=$(</tmp/${CONFIG_SECRET_NAME}/user)
OCP_PASS=$(</tmp/${CONFIG_SECRET_NAME}/password)
OPS_PROJECT=$(</tmp/${CONFIG_SECRET_NAME}/ops_project)
APP_PROJECT=$(</tmp/${CONFIG_SECRET_NAME}/app_project)

# Clone the source code
git clone ${SOURCE_URI} ${SRC_DIR}
cd ${OCP_DIR}

# Login to OCP
oc login ${MASTER_URL} -u${OCP_USER} -p${OCP_PASS} --insecure-skip-tls-verify=true
# Parse OCP template
OCP_OBJECTS=$(oc process -f ${TEMPLATE_NAME} -pAPP_PROJECT=${APP_PROJECT} -pOPS_PROJECT=${OPS_PROJECT})
# Create IS and BC
echo ${OCP_OBJECTS} | oc apply -f -
# Set BuildConfig and ImageStreams name
for row in $(echo ${OCP_OBJECTS}| jq -c '.items[]'); do
    kind=$(echo ${row} | jq -r '.kind');
    if [[ "$kind" == "BuildConfig" ]]; then
        BUILD_CONFIG_NAME=$(echo ${row} | jq -r '.metadata.name')
    fi
    if [[ "$kind" == "ImageStream" ]]; then
        IMAGE_STREAM_NAME=$(echo ${row} | jq -r '.metadata.name')
    fi
done

# Start build
oc start-build -F ${BUILD_CONFIG_NAME} -n ${OPS_PROJECT}
# Create new tag
COMMIT_ID=$(oc get istag ${IMAGE_STREAM_NAME}:latest -n ${APP_PROJECT} -o json  | jq -r ".image.dockerImageMetadata.Config.Labels.\"io.openshift.build.commit.id\"" | cut -c1-7)
oc tag ${IMAGE_STREAM_NAME}:latest ${IMAGE_STREAM_NAME}:${COMMIT_ID} -n ${APP_PROJECT}

