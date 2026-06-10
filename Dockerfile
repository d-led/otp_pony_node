FROM elixir:latest

RUN apt-get update && apt-get install -y \
  curl \
  build-essential \
  lsb-release \
  && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/bash

# Install ponyup using the official script
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/ponylang/ponyup/latest-release/ponyup-init.sh | sh

# Add ponyup to PATH
ENV PATH="/root/.local/share/ponyup/bin:${PATH}"

# Dynamically configure default platform depending on the CPU architecture
RUN if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then \
      ponyup default arm64-unknown-linux-ubuntu22.04; \
    else \
      ponyup default x86_64-unknown-linux-ubuntu22.04; \
    fi

# Install the latest release of ponyc
RUN ponyup update ponyc release

ENV CC=cc
COPY . /src/main/
WORKDIR /src/main
RUN ./build.sh

CMD ./test.sh
