<p align="center">
  <img alt="helm" src="https://miro.medium.com/max/626/1*RmiGt6GAWf4pkO9ohOnRaQ.png" width="250px" float="center"/>
</p>

<h1 align="center">AWS EC2 Deploy</h1>

<p align="center">
  <strong>This is a simple project that help when you want a ECS Deploy</strong>
</p>

<p align="center">
  <a href="#pre-requisites">Pre-Requisites</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#description">Description</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#environment-variables">Environment Variables</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#how-to-contribute">How to contribute</a>
</p>

## Getting Started

To use this repository you need to make a **git clone**:

```bash
git clone --depth 1 https://github.com/lpmatos/deploy-ecs.git -b master
```

This will give access on your **local machine** to this project.

## Environment variables

**Name**  |  **Description**
:---:  |  :---:
**AWS_ACCESS_KEY_ID**  |  AWS Access Key
**AWS_SECRET_ACCESS_KEY**  |  AWS Secret Access
**AWS_REGION**  |  AWS Region
**TASK_DEFINTION_NAME**  |  Task Definition name
**CLUSTER_NAME**  |  WS ECS Cluster Name
**SERVICE_NAME**  |  AWS ECS Service Name
**VALIDATE_IMAGE**  |  Docker image
**SLACK_CLI_TOKEN**  | Slack Token
**SLACK_CHANNEL**  |  Slack Channel

## 🐋 Development with Docker

Steps to build the Docker Image.

### Build

```bash
docker image build -t <IMAGE_NAME> -f <PATH_DOCKERFILE> <PATH_CONTEXT_DOCKERFILE>
docker image build -t <IMAGE_NAME> . (This context)
```

### Run

Steps to run the Docker Container.

* **Linux** running:

```bash
docker container run -d -p <LOCAL_PORT:CONTAINER_PORT> <IMAGE_NAME> <COMMAND>
docker container run -it --rm --name <CONTAINER_NAME> -p <LOCAL_PORT:CONTAINER_PORT> <IMAGE_NAME> <COMMAND>
```

* **Windows** running:

```
winpty docker.exe container run -it --rm <IMAGE_NAME> <COMMAND>
```

For more information, access the [Docker](https://docs.docker.com/) documentation or [this](docs/annotations/docker.md).

## 🐋 Development with Docker Compose

Build and run a docker-compose.

```bash
docker-compose up --build
```

Down all services deployed by docker-compose.

```bash
docker-compose down
```

Down all services and delete all images.

```bash
docker-compose down --rmi all
```

## How to contribute

1. Make a **Fork**.
2. Follow the project organization.
3. Add the file to the appropriate level folder - If the folder does not exist, create according to the standard.
4. Make the **Commit**.
5. Open a **Pull Request**.
6. Wait for your pull request to be accepted.. 🚀

Remember: There is no bad code, there are different views/versions of solving the same problem. 😊

## Add to git and push

You must send the project to your GitHub after the modifications

```bash
git add -f .
git commit -m "Added - Fixing somethings"
git push origin master
```

## Versioning

- [CHANGELOG](CHANGELOG.md)

## Project Status

* ✔️ Finish
