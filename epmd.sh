#!/usr/bin/env bash
# Starts epmd and waits until it answers.  Erlang starts it for itself; a
# machine that only has this library needs it before a node can publish.
#
# epmd -daemon forks and answers a moment later, so a publish that arrives
# first finds nothing listening and fails.
ensure_epmd() {
  if ! command -v epmd >/dev/null 2>&1; then
    return 0
  fi

  epmd -daemon 2>/dev/null || true

  local tries=0
  while ! epmd -names >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 50 ]; then
      echo "epmd did not answer; publishing needs it" >&2
      return 1
    fi
    sleep 0.1
  done
}
