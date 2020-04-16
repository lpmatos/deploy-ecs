# ==============================================================================
## DESCRIPTION: Deploy AWS ECS.
## NAME: deploy.sh
## AUTHOR: Lucca Pessoa da Silva Matos
## DATE: 16.04.2020
## VERSION: 1.0
# ==============================================================================

START=$(date +%s)

# ==============================================================================
# OUTPUT-COLORING
# ==============================================================================

# High Intensity
BLACK='\033[0;90m'       # Black
RED='\033[0;91m'         # Red
GREEN='\033[0;92m'       # Green
YELLOW='\033[0;93m'      # Yellow
BLUE='\033[0;94m'        # Blue
PURPLE='\033[0;95m'      # Purple
CYAN='\033[0;96m'        # Cyan
NC='\033[0;97m'          # White

# ==============================================================================
# VALUES
# ==============================================================================

[ ! "${AWS_REGION}" ] && [ "${AWS_REGION}" == "" ] && AWS_REGION=us-east-1 || echo -e "\n${GREEN}AWS Region exist and is not empty${NC}"
[ ! "${AWS_ACCESS_KEY_ID}" ] && [ "${AWS_ACCESS_KEY_ID}" == "" ] && { echo -e "\n${RED}AWS Access Key is empty or not exist. Bye bye!${NC}"; exit 1; } || echo -e "${GREEN}AWS Access Key exist and is not empty${NC}"
[ ! "${AWS_SECRET_ACCESS_KEY}" ] && [ "${AWS_SECRET_ACCESS_KEY}" == "" ] && { echo -e "\n${RED}AWS Secret Key is empty or not exist. Bye bye!${NC}"; exit 1; } || echo -e "${GREEN}AWS Secret Key exist and is not empty${NC}"
[ ! "${TASK_DEFINTION_NAME}" ] && [ "${TASK_DEFINTION_NAME}" == "" ] && { echo -e "\n${RED}Task Definition Name is empty or not exist. Bye bye!${NC}"; exit 1; } || echo -e "${GREEN}Task Definition Name exist and is not empty${NC}"
[ ! "${CLUSTER_NAME}" ] && [ "${CLUSTER_NAME}" == "" ] && { echo -e "\n${RED}Cluster name is empty or not exist. Bye bye!${NC}"; exit 1; } || echo -e "${GREEN}Cluster Name exist and is not empty${NC}"
[ ! "${SERVICE_NAME}" ] && [ "${SERVICE_NAME}" == "" ] && { echo -e "\n${RED}Service name is empty or not exist. Bye bye!${NC}"; exit 1; } || echo -e "${GREEN}Service Name exist and is not empty${NC}"
[ ! "${VALIDATE_IMAGE}" ] && [ "${VALIDATE_IMAGE}" == "" ] && VALIDATE_IMAGE=${REPOSITORY_URL}:${CI_COMMIT_SHORT_SHA} || echo -e "\n${GREEN}Validate image exist and is not empty${NC}"
[ ! "${SLACK_CHANNEL}" ] && [ "${SLACK_CHANNEL}" == "" ] && { echo -e "\n${RED}Slack Channel is empty or not exist. Bye bye!${NC}"; exit 1; } || echo -e "${GREEN}Slack Channel exist and is not empty${NC}"

OS=`uname`

[ "${OS}" = "Linux" ] && DATE_CMD="date" || DATE_CMD="gdate"
DATE_INFO=$(${DATE_CMD} +"%Y-%m-%d %T")
DATE_INFO_SHORT=$(${DATE_CMD} +"%A %B")
USER=$(whoami)

# =============================================================================
# FUNCTIONS
# =============================================================================

function MissingFiglet(){
  cat <<EOF
You need to install figlet to use this plugin:
    COMMAND: apk update && apk add figlet
EOF
}

# =============================================================================

function MissingAWSCLI(){
  cat <<EOF
You need to install AWS CLI this plugin:
    COMMAND: pip install awscli
EOF
}

# =============================================================================

function Welcome(){
  echo -e "\n"
  echo "AWS ECS Deploy" | figlet
  echo -e "\n-------------------------------------------------"
  echo "* Welcome ${USER}! It's now ${DATE_INFO_SHORT}"
  echo -e "* ${DATE_INFO}"
  echo -e "* System - ${OS}"
  echo -e "*"
  echo -e "* Autor: ${YELLOW}Lucca Pessoa da Silva Matos${YELLOW}${NC}"
  echo -e "* Description: ${BLUE}Script to help with AWS ECS deploys${BLUE}${NC}"
  echo -e "-------------------------------------------------\n"
}

# =============================================================================

function Status() {
  echo -e "[DEPLOY]: ${1}"
}

# =============================================================================

function WaitForService() {
  Status "Waiting for ECS service ${SERVICE_NAME} to become stable on ${CLUSTER_NAME} cluster..."
  aws ecs wait services-stable --region ${AWS_REGION} --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME}
  Status "Done! ECS services stable."
}

# =============================================================================

function Time() {
  if [[ -z ${1} || ${1} -lt 60 ]] ;then
    min=0 ; secs="${1}"
  else
    time_mins=$(echo "scale=2; ${1}/60" | bc)
    min=$(echo ${time_mins} | cut -d'.' -f1)
    secs="0.$(echo ${time_mins} | cut -d'.' -f2)"
    secs=$(echo ${secs}*60|bc|awk '{print int($1+0.5)}')
  fi
  echo "${min} minutes and ${secs} seconds."
}

# =============================================================================
# MAIN
# =============================================================================

[ $(which figlet 2> /dev/null) ] || { MissingFiglet; exit 1; }
[ $(which aws 2> /dev/null) ] || { MissingAWSCLI; exit 1; }

Welcome

slack chat send --pretext "⚠️ ECS Deploy - A new deploy has started ⚠️" \
 --title "Information:" \
 --text "*Date Info*: ${DATE_INFO}\n*Status*: Running\n*Service:* ${SERVICE_NAME}\n*Cluster*: ${CLUSTER_NAME}\n*Current Task:* ${TASK_DEFINTION_NAME}" "${SLACK_CHANNEL}"

echo -e "\nGetting Task Definition..."
TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition "${TASK_DEFINTION_NAME}" --region "${AWS_REGION}" 2> /dev/null)

echo -e "\nGetting New Container Definition..."
NEW_CONTAINER_DEFINTIION=$(echo ${TASK_DEFINITION} | jq --arg IMAGE "${VALIDATE_IMAGE}" '.taskDefinition.containerDefinitions[0].image = $IMAGE | .taskDefinition.containerDefinitions[0]' 2> /dev/null)

echo -e "\nRegistering new container definition..."
TASK_VERSION=$(aws ecs register-task-definition --region "${AWS_REGION}" --family ${TASK_DEFINTION_NAME} --container-definitions "${NEW_CONTAINER_DEFINTIION}" | jq --raw-output '.taskDefinition.revision')

echo -e "\nRegistered ECS Task Definition: ${TASK_VERSION}"

if [ -n "${TASK_VERSION}" ]; then
  echo -e "\nUpdate ECS Cluster: ${CLUSTER_NAME}"
  echo "Service: ${SERVICE_NAME}"
  echo "Task Definition: ${TASK_DEFINTION_NAME}:${TASK_VERSION}"
  echo -e "\nAWS ECS Update Service with new Task Definition..."
  DEPLOYED_SERVICE=$(aws ecs update-service --region "${AWS_REGION}" --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${TASK_DEFINTION_NAME}:${TASK_VERSION} | jq --raw-output '.service.serviceName')
  echo -e "\nDeployment of ${DEPLOYED_SERVICE} ${GREEN}complete!${NC}\n"
else
  END=$(date +%s)
  DIFERENCE="$((${END} - ${START}))"
  RESULT=$(Time ${DIFERENCE})
  slack chat send --pretext "❌ ECS Deploy - No Task Definition ❌" \
  --title "Information:" \
  --text "*Date Info*: ${DATE_INFO}\n*Status*: Running\n*Service:* ${SERVICE_NAME}\n*Cluster*: ${CLUSTER_NAME}\n*Current Task:* ${TASK_DEFINTION_NAME}\n*Time Elapsed*: ${RESULT}" "${SLACK_CHANNEL}"
  echo -e "${RED}\nNo task definition. Exit...${NC}" && exit 1;
fi

WaitForService

END=$(date +%s)
DIFERENCE="$((${END} - ${START}))"
RESULT=$(Time ${DIFERENCE})

slack chat send --pretext "✔️ ECS Deploy - Deploy was successfully completed ✔️" \
 --title "Information:" \
 --text "*Date Info*: ${DATE_INFO}\n*Status*: Done - ECS Service Stable\n*Service:* ${SERVICE_NAME}\n*Cluster*: ${CLUSTER_NAME}\n*Old Task*: ${TASK_DEFINTION_NAME}\n*New Task:* ${TASK_DEFINTION_NAME}:${TASK_VERSION}\n*Time Elapsed*: ${RESULT}" "${SLACK_CHANNEL}"
