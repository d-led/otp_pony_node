#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# run this in one terminal and after that, ./otp_pony_node in another

elixir --sname demo@localhost --cookie secretcookie demo.exs
