# ==============================================================================
## DESCRIPTION: Deploy AWS ECS.
## NAME: deploy.sh
## AUTHOR: Lucca Pessoa da Silva Matos
## DATE: 17.04.2020
## VERSION: 1.0
## RUN:
##      > chmod a+x ./deploy.sh && bash deploy.sh -h
# ==============================================================================

START=$(date +%s)

# ==============================================================================
# OUTPUT-COLORING
# ==============================================================================

# High Intensity
BLACK="\033[0;90m"       # Black
RED="\033[0;91m"         # Red
GREEN="\033[0;92m"       # Green
YELLOW="\033[0;93m"      # Yellow
BLUE="\033[0;94m"        # Blue
PURPLE="\033[0;95m"      # Purple
CYAN="\033[0;96m"        # Cyan
NC="\033[0;97m"          # White

# ==============================================================================
# VALUES
# ==============================================================================

OS=`uname`
[ "${OS}" = "Linux" ] && DATE_CMD="date" || DATE_CMD="gdate"
DATE_INFO=$(${DATE_CMD} +"%Y-%m-%d %T")
DATE_INFO_SHORT=$(${DATE_CMD} +"%A %B")
USER=$(whoami)

# ==============================================================================
# FUNCTIONS
# ==============================================================================

function Status() {
  echo -e "\n[DEPLOY]: ${1}"
}

function Welcome() {
  echo -e "\n"
  echo "AWS ECS Deploy" | figlet
  echo -e "\n-------------------------------------------------"
  echo "* Welcome ${USER}! It's now ${DATE_INFO_SHORT}"
  echo -e "* ${DATE_INFO}"
  echo -e "* System - ${OS}"
  echo -e "*"
  echo -e "* Autor: ${YELLOW}Lucca Pessoa da Silva Matos${YELLOW}${NC}"
  echo -e "* Description: ${BLUE}Script to help with AWS ECS deploys${BLUE}${NC}"
  echo -e "* Version: ${YELLOW}1.0.0${YELLOW}${NC}"
  echo -e "-------------------------------------------------\n"
}

function Help() {
  local PROGNAME=$(basename ${0})
  echo -e "\n${CYAN}Script $PROGNAME: By ${YELLOW}Lucca Pessoa da Silva Matos.${NC}"
  cat <<EOF

Description: Deploy ECS from Bash.

Flags:
  -c, c, cluster, --cluster             AWS ECS Cluster Name
  -s, s, service, --service             AWS ECS Service Name
  -r, r, region, --region               AWS Region Name
  -i, i, image, --image                 Image Used in ECS Task
  aws-access, --aws-access              AWA Access Key
  aws-secret, --aws-secret              AWA Secret Key
  task-name, --task-name                Task Definition Name
  slack-channel, --slack-channe         Slack Channel Name
  slack-token, --slack-token            Slack CLI Token
  -h, h, help, --help                   Show this help message

EOF
}

function AssertIsInstalled() {
  local readonly PACKAGE="$1"
  if [[ ! $(command -v ${PACKAGE}) ]]; then
    echo -e "\n${RED}ERROR: The binary '${PACKAGE}' is required by this script but is not installed or in the system's PATH.${NC}\n"
    exit 1
  fi
}

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

function CheckAWSVariables() {
  [ ! "${AWS_REGION}" ] && [ "${AWS_REGION}" == "" ] && \
      AWS_REGION=us-east-1 || \
        echo -e "\n${GREEN}AWS Region exist and is not empty${NC}"
  [ ! "${AWS_ACCESS_KEY_ID}" ] && [ "${AWS_ACCESS_KEY_ID}" == "" ] && \
      { echo -e "\n${RED}AWS Access Key is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}AWS Access Key exist and is not empty${NC}"
  [ ! "${AWS_SECRET_ACCESS_KEY}" ] && [ "${AWS_SECRET_ACCESS_KEY}" == "" ] && \
      { echo -e "\n${RED}AWS Secret Key is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}AWS Secret Key exist and is not empty${NC}"
}

function CheckSlackVariables() {
  [ ! "${SLACK_CHANNEL}" ] && [ "${SLACK_CHANNEL}" == "" ] && \
      { echo -e "\n${RED}Slack Channel is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}Slack Channel exist and is not empty${NC}"
  [ ! "${SLACK_CLI_TOKEN}" ] && [ "${SLACK_CLI_TOKEN}" == "" ] && \
      { echo -e "\n${RED}Slack CLI Token is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}Slack CLI Token exist and is not empty${NC}"
}

function CheckGeneralVariables() {
  [ ! "${CLUSTER_NAME}" ] && [ "${CLUSTER_NAME}" == "" ] && \
      { echo -e "\n${RED}Cluster name is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}Cluster Name exist and is not empty${NC}"
  [ ! "${SERVICE_NAME}" ] && [ "${SERVICE_NAME}" == "" ] && \
      { echo -e "\n${RED}Service name is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}Service Name exist and is not empty${NC}"
  [ ! "${TASK_DEFINTION_NAME}" ] && [ "${TASK_DEFINTION_NAME}" == "" ] && \
      { echo -e "\n${RED}Task Definition Name is empty or not exist. Bye bye!${NC}"; exit 1; } || \
          echo -e "${GREEN}Task Definition Name exist and is not empty${NC}"
  [ ! "${VALIDATE_IMAGE}" ] && [ "${VALIDATE_IMAGE}" == "" ] && \
      VALIDATE_IMAGE=${REPOSITORY_URL}:${CI_COMMIT_SHORT_SHA} || \
          echo -e "${GREEN}Validate image exist and is not empty\n${NC}"
}

function WaitForService() {
  Status "Waiting for ECS service ${2} to become stable on ${1} cluster..."
  aws ecs wait services-stable --region ${3} --cluster ${1} --service ${2}
  Status "Done! ECS services stable."
}

function GetECSInfo() {
  TASKS_DEFINITION=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --region "${AWS_REGION}" 2> /dev/null)

  CURRENT_DESIRED_COUNT=$(echo ${TASKS_DEFINITION} | jq --raw-output '.services[0].desiredCount')
  CURRENT_PENDING_COUNT=$(echo ${TASKS_DEFINITION} | jq --raw-output '.services[0].pendingCount')
  CURRENT_RUNNING_COUNT=$(echo ${TASKS_DEFINITION} | jq --raw-output '.services[0].runningCount')
  CURRENT_STATUS=$(echo ${TASKS_DEFINITION} | jq --raw-output '.services[0].status')
  CURRENT_TASK_REVISION=$(echo ${TASKS_DEFINITION} | jq --raw-output '.services[0].taskDefinition')

  Status "Getting Task Status..."
  echo -e "\n${YELLOW}Current Desired Count${NC}: ${CURRENT_DESIRED_COUNT}"
  echo -e "${YELLOW}Current Pending Count${NC}: ${CURRENT_PENDING_COUNT}"
  echo -e "${YELLOW}Current Running Count${NC}: ${CURRENT_RUNNING_COUNT}"
  echo -e "${YELLOW}Current Status${NC}: ${CURRENT_STATUS}"
  echo -e "${YELLOW}Current Task Revision${NC}: ${CURRENT_TASK_REVISION}\n"
}

function ECSDeploy() {
  Status "Getting Task Definition..."
  TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition "${TASK_DEFINTION_NAME}" --region "${AWS_REGION}" 2> /dev/null)

  Status "Getting New Container Definition..."
  NEW_CONTAINER_DEFINTIION=$(echo ${TASK_DEFINITION} | jq --arg IMAGE "${VALIDATE_IMAGE}" '.taskDefinition.containerDefinitions[0].image = $IMAGE | .taskDefinition.containerDefinitions[0]' 2> /dev/null)

  Status "Registering new container definition with a new image..."
  TASK_VERSION=$(aws ecs register-task-definition --region "${AWS_REGION}" --family ${TASK_DEFINTION_NAME} --container-definitions "${NEW_CONTAINER_DEFINTIION}" | jq --raw-output '.taskDefinition.revision')

  Status "Registered ECS Task Definition: ${TASK_VERSION}"

  if [ -n "${TASK_VERSION}" ]; then
    Status "Update ECS Cluster: ${CLUSTER_NAME}"
    echo -e "\n${YELLOW}Service${NC}: ${SERVICE_NAME}"
    echo -e "${YELLOW}Task Definition${NC}: ${TASK_DEFINTION_NAME}:${TASK_VERSION}"
    Status "AWS ECS Update Service with new Task Definition..."
    DEPLOYED_SERVICE=$(aws ecs update-service --region "${AWS_REGION}" --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${TASK_DEFINTION_NAME}:${TASK_VERSION} | jq --raw-output '.service.serviceName')
    Status "Deployment of ${DEPLOYED_SERVICE} ${GREEN}complete!${NC}"
  else
    END=$(date +%s)
    DIFERENCE="$((${END} - ${START}))"
    RESULT=$(Time ${DIFERENCE})
    slack chat send --pretext "❌ ECS Deploy - Failed to register Task Definition ❌" \
    --title "Information:" \
    --text "*Date Info*: ${DATE_INFO}\n*Status*: Running\n*Service:* ${SERVICE_NAME}\n*Cluster*: ${CLUSTER_NAME}\n*Current Task:* ${TASK_DEFINTION_NAME}\n*Time Elapsed*: ${RESULT}" \
    --channel ${SLACK_CHANNEL} \
    --token ${SLACK_CLI_TOKEN} 2> /dev/null
    Status "${RED}Failed to register Task Definition. Exit...${NC}" && exit 1;
  fi

  WaitForService ${CLUSTER_NAME} ${SERVICE_NAME} ${AWS_REGION}

  END=$(date +%s)
  DIFERENCE="$((${END} - ${START}))"
  RESULT=$(Time ${DIFERENCE})
}

# ==============================================================================
# OPTIONS
# ==============================================================================

while [[ $# > 0 ]]; do
  CMD=${1}
  case $CMD in
    "aws-access"|"-aws-access"|"--aws-access")
      AWS_ACCESS_KEY_ID=$(echo ${2} && ${AWS_ACCESS_KEY_ID} || "")
      shift ;;
    "aws-secret"|"-aws-secret"|"--aws-secret")
      AWS_SECRET_ACCESS_KEY=$(echo ${2} && ${AWS_SECRET_ACCESS_KEY} || "")
      shift ;;
    "c"|"-c"|"cluster"|"--cluster")
      CLUSTER_NAME=$(echo ${2} && ${CLUSTER_NAME} || "")
      shift ;;
    "s"|"-s"|"service"|"--service")
      SERVICE_NAME=$(echo ${2} && ${SERVICE_NAME} || "")
      shift ;;
    "r"|"-r"|"region"|"--region")
      AWS_REGION=$(echo ${2} && ${AWS_REGION} || "")
      shift ;;
    "i"|"-i"|"image"|"--image")
      VALIDATE_IMAGE=$(echo ${2} && ${VALIDATE_IMAGE} || "")
      shift ;;
    "-task-name"|"task-name"|"--task-name")
      TASK_DEFINTION_NAME=$(echo ${2} && ${TASK_DEFINTION_NAME} || "")
      shift ;;
    "-slack-channel"|"slack-channel"|"--slack-channel")
      SLACK_CHANNEL=$(echo ${2} && ${SLACK_CHANNEL} || "#validation")
      if [ $SLACK_CHANNEL =~ "#" ]; then
        echo -e "\nSlack Channel is Okay!"
      else
        echo -e "\nAdding # in Slack Channel"
        SLACK_CHANNEL="#${SLACK_CHANNEL}"
      fi
      shift ;;
    "-slack-token"|"slack-token"|"--slack-token")
      SLACK_CLI_TOKEN=$(echo ${2} && ${SLACK_CLI_TOKEN} || "")
      shift ;;
    "help"|"-h"|"h"|"--help")
      Help && exit 1 ;;
    *)
      echo "${RED}ERROR: Unrecognized argument: ${CMD}${NC}"
      Help && exit 1 ;;
  esac
  shift
done

# ==============================================================================
# MAIN
# ==============================================================================

Welcome && AssertIsInstalled "figlet" && AssertIsInstalled "aws" && \
  AssertIsInstalled "slack" && AssertIsInstalled "bc" && \
  CheckAWSVariables && CheckSlackVariables && CheckGeneralVariables

GetECSInfo ${CLUSTER_NAME} ${SERVICE_NAME} ${AWS_REGION} && slack chat send --pretext "⚠️ ECS Deploy - A new deploy has started ⚠️" \
--title "Information:" \
--text "*Date Info*: ${DATE_INFO}\n*Status*: Running\n*Service:* ${SERVICE_NAME}\n*Cluster*: ${CLUSTER_NAME}\n*Current Task:* ${TASK_DEFINTION_NAME}" \
--channel ${SLACK_CHANNEL} \
--token ${SLACK_CLI_TOKEN} 2> /dev/null

ECSDeploy

GetECSInfo ${CLUSTER_NAME} ${SERVICE_NAME} ${AWS_REGION}

slack chat send --pretext "✔️ ECS Deploy - Deploy was successfully completed ✔️" \
--title "Information:" \
--text "*Date Info*: ${DATE_INFO}\n*Status*: Done - ECS Service Stable\n*Service:* ${SERVICE_NAME}\n*Cluster*: ${CLUSTER_NAME}\n*Old Task*: ${TASK_DEFINTION_NAME}\n*New Task:* ${TASK_DEFINTION_NAME}:${TASK_VERSION}\n*Time Elapsed*: ${RESULT}" \
--channel ${SLACK_CHANNEL} \
--token ${SLACK_CLI_TOKEN} 2> /dev/null
