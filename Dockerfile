ARG PYTHON_VERSION=3.8-alpine3.11

FROM python:${PYTHON_VERSION}

LABEL maintainer="Lucca Pessoa da Silva Matos - luccapsm@gmail.com" \
        org.label-schema.version="1.0.0" \
        org.label-schema.release-data="15-04-2020" \
        org.label-schema.url="https://github.com/lpmatos/deploy-ecs" \
        org.label-schema.alpine="https://alpinelinux.org/" \
        org.label-schema.python="https://www.python.org/" \
        org.label-schema.aws="https://aws.amazon.com/pt/cli/" \
        org.label-schema.name="AWS Deploy ECS"

ENV PATH="/root/.local/bin:$PATH" \
    PYTHONIOENCODING=UTF-8

RUN set -ex && apk update && apk add --no-cache --update \
      bash=5.0.11-r1 \
      curl=7.67.0-r0 \
      openssl=1.1.1d-r3 \
      figlet=2.2.5-r0 \
      jq=1.6-r0

RUN curl -O https://raw.githubusercontent.com/rockymadden/slack-cli/master/src/slack && \
    chmod +x slack && \
    mv ./slack /usr/bin

ARG AWS_CLI_VERSION=1.18.39

RUN pip install --user awscli==${AWS_CLI_VERSION}

COPY [ "./code", "." ]

RUN find ./ -iname "*.sh" -type f -exec chmod a+x {} \; -exec echo {} \;;

ENTRYPOINT []

CMD [ "sh" ]
