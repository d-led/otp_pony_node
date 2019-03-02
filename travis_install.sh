#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
apt-get update
apt-get install -y build-essential \
    elixir \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E04F0923 B3B48BDA
add-apt-repository "deb https://dl.bintray.com/pony-language/ponylang-debian  $(lsb_release -cs) main"
apt-get update

apt-get -y install ponyc
