FROM elixir:latest

RUN apt-get update && apt-get install -y \
  curl \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/bash

# Install ponyup using the official script
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/ponylang/ponyup/latest-release/ponyup-init.sh | sh

# Add ponyup to PATH
ENV PATH="/root/.local/share/ponyup/bin:${PATH}"

# Install the latest release of ponyc
RUN ponyup update ponyc release

ENV CC=cc
COPY . /src/main/
WORKDIR /src/main
RUN ./build.sh

CMD ./test.sh
