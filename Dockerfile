FROM elixir:latest

RUN apt-get update && apt-get install -y \
  curl \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

ENV SHELL=bash
RUN sh -c "$(curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/ponylang/ponyup/latest-release/ponyup-init.sh)"
RUN ln -s /usr/local/lib/erlang /usr/lib/erlang && PATH=/root/.local/share/ponyup/bin:$PATH ponyup update ponyc release

ENV CC=cc
COPY . /src/main/
WORKDIR /src/main
RUN ./build.sh

CMD ./test.sh
