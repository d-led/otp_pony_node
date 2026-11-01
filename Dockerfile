FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash

# Erlang/Elixir from the distribution: erlang-dev brings ei.h together with the
# static archive libei.a that the shim links.  lsb-release is what ponyup uses to
# work out which ponyc build to download, so the platform is never hard coded.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        elixir \
        erlang-dev \
        git \
        lsb-release \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf \
        https://raw.githubusercontent.com/ponylang/ponyup/latest-release/ponyup-init.sh | sh
ENV PATH="/root/.local/share/ponyup/bin:${PATH}"
RUN ponyup update ponyc release

COPY . /src/main/
WORKDIR /src/main
RUN ./build.sh

# Unit tests, then a round trip through a real Elixir node.
CMD ["bash", "-lc", "./test.sh && ./integration.sh"]
