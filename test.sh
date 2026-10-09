#!/usr/bin/env bash
#
# test.sh — Run the GitLab CI/CD pipeline locally with gitlab-ci-local.
#
# `gitlab-ci-local` executes your real .gitlab-ci.yml jobs in Docker on your
# machine, so you can validate CI wiring before pushing to GitLab. See
# https://github.com/firecow/gitlab-ci-local
#
# NOTE: this project's build/deploy steps need an image builder. On machines using
# Rancher Desktop (socket under ~/.rd/) or Docker Desktop with restricted dind, the
# in-container Docker build cannot run, so `test.sh` builds/serves the image on the
# HOST via the docker CLI as a faithful fallback. See README.md "Local testing".
#
# Usage:
#   ./test.sh                 # auto: lint (gitlab-ci-local) + host build+serve test
#   ./test.sh list            # validate YAML and print all jobs/stages
#   ./test.sh lint            # run the self-contained lint-workflow job via gitlab-ci-local
#   ./test.sh build           # host-side Docker build + curl validation only
#   ./test.sh install         # only install/upgrade gitlab-ci-local

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GCL_VERSION="4.74.0"           # Minimum version we want installed.
IMAGE_REF="${NYAN_IMAGE:-nyan-cat:local}"

log()  { printf '\n\033[94m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[92m✓ %s\033[0m\n' "$*"; }
warn() { printf '    \033[93m⚠ %s\033[0m\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- install -----------------------------------------------------------------

install_gitlab_ci_local() {
  if have gitlab-ci-local; then
    local cur; cur="$(gitlab-ci-local --version 2>/dev/null | tr -d 'v' || echo 0)"
    if awk "BEGIN{exit !($cur >= $GCL_VERSION)}"; then
      ok "gitlab-ci-local already installed: v$(gitlab-ci-local --version)"
      return 0
    fi
    warn "Installed version ($cur) is older than required ($GCL_VERSION). Reinstalling."
  fi

  log "Installing gitlab-ci-local"
  if have brew; then
    brew install gitlab-ci-local || { warn "brew install failed."; return 1; }
  elif have npm; then
    npm install -g "gitlab-ci-local@$GCL_VERSION" || { warn "npm install failed."; return 1; }
  else
    warn "Neither 'brew' nor 'npm' found. Install gitlab-ci-local manually, then re-run:"
    warn "  ./test.sh list"
    return 1
  fi

  ok "Installed: v$(gitlab-ci-local --version)"
}

# --- lint stage (runs inside gitlab-ci-local) --------------------------------

list_jobs() {
  log "Validating .gitlab-ci.yml and listing jobs"
  ( cd "$REPO_ROOT" && gitlab-ci-local --list )
  ok "YAML is valid."
}

run_lint() {
  log "Running the self-contained lint-workflow stage via gitlab-ci-local"
  ( cd "$REPO_ROOT" && gitlab-ci-local lint-workflow )
  ok "lint-workflow passed."
}

# --- host-side build+serve fallback ------------------------------------------

host_build_test() {
  if ! have docker; then
    warn "Docker is not installed or not on PATH. Install Docker Desktop/Rancher Desktop and retry."
    exit 1
  fi

  log "Building image ${IMAGE_REF} from ./Dockerfile (host docker)"
  docker build -t "$IMAGE_REF" "$REPO_ROOT"

  log "Starting container to validate the served page"
  local cid; cid="$(docker run -d --rm -p 8085:80 "$IMAGE_REF")"
  trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT

  local attempts=30
  until curl -fsS http://localhost:8085/ >/dev/null 2>&1 || [ "$attempts" -eq 0 ]; do
    sleep 1; attempts=$((attempts - 1))
  done

  log "Fetching the page back from NGINX"
  local body; body="$(curl -fsS http://localhost:8085/ || true)"

  printf '%s' "$body" | grep -qi "Nyan Cat"        && ok "Page served and contains 'Nyan Cat' content."          || warn "Missing 'Nyan Cat' content in served HTML."
  printf '%s' "$body" | grep -qi "youtube.com/embed" && ok "Embedded YouTube iframe is present."                  || warn "No embedded video iframe found in served HTML."

  local server; server="$(curl -fsSI http://localhost:8085/ | grep -i '^server:' || echo 'server: unknown')"
  ok "Server header: $(printf '%s' "$server" | tr -d '\r')"

  log "Cleaning up container ${cid}"
  docker rm -f "$cid" >/dev/null 2>&1 || true
  trap - EXIT

  ok "Local build + validation complete. Image tag: ${IMAGE_REF}"
}

# --- dispatch ----------------------------------------------------------------

main() {
  local mode="${1:-auto}"
  case "$mode" in
    install)   install_gitlab_ci_local ;;
    list)      install_gitlab_ci_local && list_jobs ;;
    lint)      install_gitlab_ci_local && run_lint ;;
    build)     host_build_test ;;
    auto|"")
      if ! have gitlab-ci-local || ! awk "BEGIN{exit !($(gitlab-ci-local --version 2>/dev/null | tr -d 'v' || echo 0) >= $GCL_VERSION)}"; then
        install_gitlab_ci_local
      fi
      list_jobs && run_lint && host_build_test
      ;;
    *) echo "Usage: $0 {install|list|lint|build}"; exit 2 ;;
  esac
}

main "$@"
