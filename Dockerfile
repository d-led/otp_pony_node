# The toolchain the Native CI job installs.  setup-beam resolves
# `otp-version: 27.2` to the newest 27.2.x on ubuntu-latest, and this image is
# that OTP and Elixir on the same Ubuntu release, so a local run and a CI run
# differ only in the runner.
FROM hexpm/elixir:1.18.2-erlang-27.2.4-ubuntu-noble-20250925

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
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

CMD ["bash", "-lc", "./test.sh && ./integration.sh"]
