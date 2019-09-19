#! /usr/bin/env bash

# Description:
#   Runs the integration tests for metal3-dev-env
#   Requires:
#     - source stackrc file
#     - openstack ci infra should already be deployed.
#     - environment variables set:
#       - AIRSHIP_CI_USER: Ci user for jumphost.
#       - AIRSHIP_CI_USER_KEY: Path of the CI user private key for jumphost.
#       - GITHUB_USERNAME: Username for Github API
#       - GITHUB_PASSWORD: Password for Github API
#       - BUILD_URL: The URL of the current build
#       - PR_ID : The id of the pull request
#       - REPO_ORG: the organization of the repository
#       - REPO_NAME: the name of the repo
# Usage:
#  integration_test_ci_wrapper.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
TESTS_SCRIPTS_DIR="${CI_DIR}/scripts/tests"

DISTRIBUTION="${DISTRIBUTION:-ubuntu}"
if [ "${DISTRIBUTION}" == "ubuntu" ]
then
  DISTRIBUTION_NAME="Ubuntu"
else
  DISTRIBUTION_NAME="CentOS"
fi

echo "Setting status on Github PR"
curl -H "Authorization: token ${GITHUB_PASSWORD}" -X POST \
-d "{\"body\": \":revolving_hearts: ${DISTRIBUTION_NAME} Test pending : \
${BUILD_URL}\", \"event\": \"COMMENT\"}" \
"https://api.github.com/repos/${REPO_ORG}/${REPO_NAME}/pulls/${PR_ID}/reviews" \
 > /dev/null 2> /dev/null

"$TESTS_SCRIPTS_DIR/integration_test.sh"
RETURN_CODE="$?"

if [[ "$RETURN_CODE" == "0" ]]; then
  echo -e "\n\n\n\nTests SUCCEEDED\n\n\n\n"
  RETURN_STATUS=":green_heart: Test Success"
else
  echo -e "\n\n\n\nTests FAILED\n\n\n\n"
  RETURN_STATUS=":broken_heart: Test Failure"
fi

echo "Setting status on Github PR"
curl -H "Authorization: token ${GITHUB_PASSWORD}" -X POST \
-d "{\"body\": \"${RETURN_STATUS} ${DISTRIBUTION_NAME} : ${BUILD_URL}\", \
\"event\": \"COMMENT\"}" \
"https://api.github.com/repos/${REPO_ORG}/${REPO_NAME}/pulls/${PR_ID}/reviews" \
 > /dev/null 2> /dev/null

exit "${RETURN_CODE}"
