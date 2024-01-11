FROM elixir:latest

RUN apt-get update && apt-get install -y \
  curl \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

ENV SHELL=bash
RUN curl https://dl.cloudsmith.io/public/ponylang/releases/raw/versions/0.8.0/ponyup-x86-64-unknown-linux.tar.gz -o ponyup.tgz
RUN mkdir -p /root/.local/share/ponyup/bin/ && mkdir -p /tmp/ponyup && tar xvzf ponyup.tgz -C /tmp/ponyup && mv /tmp/ponyup/*/bin/* /root/.local/share/ponyup/bin
RUN echo "x86_64-linux-ubuntu20.04" > /root/.local/share/ponyup/.platform && ln -sf /root/.local/share/ponyup/bin/ponyup /usr/bin/ponyup && ponyup default "x86_64-linux-ubuntu20.04"
RUN ln -sf /usr/local/lib/erlang /usr/lib/erlang && ponyup update ponyc release && ln -sf /root/.local/share/ponyup/bin/ponyc /usr/bin/ponyc

ENV CC=cc
COPY . /src/main/
WORKDIR /src/main
RUN ./build.sh

CMD ./test.sh
