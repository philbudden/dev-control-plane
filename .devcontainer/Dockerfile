FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        curl \
        git \
        jq \
        openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
