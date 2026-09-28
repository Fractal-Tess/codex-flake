#!/usr/bin/env bash
set -euo pipefail

readonly UPSTREAM_REPO="openai/codex"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

github_api_get() {
  local url="$1"
  local -a args=(
    --silent --show-error --fail --location
    --header "Accept: application/vnd.github+json"
    --header "X-GitHub-Api-Version: 2022-11-28"
    --header "User-Agent: Fractal-Tess/codex-flake"
  )
  if [[ -n "${GH_TOKEN:-}" ]]; then
    args+=(--header "Authorization: Bearer ${GH_TOKEN}")
  fi
  curl "${args[@]}" "$url"
}

asset_digest() {
  local release_json="$1"
  local asset_name="$2"
  local digest
  digest="$(jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .digest' <<<"$release_json")"
  [[ "$digest" == sha256:* ]] || fail "missing SHA-256 digest for ${asset_name}"
  printf '%s\n' "${digest#sha256:}"
}

to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

# Codex tags Rust releases as `rust-v<version>` and also publishes unrelated
# tags and a steady stream of `-alpha` prereleases. `releases/latest` usually
# points at the newest stable `rust-v` tag, but when it does not, fall back to
# scanning the release list for the newest stable one.
latest_stable_release() {
  local release_json
  release_json="$(github_api_get "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest")"
  if jq -e '.tag_name | startswith("rust-v")' <<<"$release_json" >/dev/null \
    && [[ "$(jq -r '.draft or .prerelease' <<<"$release_json")" == "false" ]]; then
    printf '%s\n' "$release_json"
    return 0
  fi

  github_api_get "https://api.github.com/repos/${UPSTREAM_REPO}/releases?per_page=100" \
    | jq -e 'map(select(.draft == false and .prerelease == false and (.tag_name | startswith("rust-v")))) | .[0]' \
    || fail "could not find a stable rust-v release"
}

main() {
  local requested_version="${1:-}"
  local current_version release_json version x86_hash arm64_hash x86_host_hash arm64_host_hash

  require_tool curl
  require_tool jq
  require_tool nix
  require_tool sed

  cd "$ROOT_DIR"
  current_version="$(sed -n 's/^  version = "\([^"]*\)";/\1/p' packages/codex.nix)"
  [[ -n "$current_version" ]] || fail "could not read the packaged version"

  if [[ -n "$requested_version" ]]; then
    version="${requested_version#rust-v}"
    version="${version#v}"
    release_json="$(github_api_get "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/rust-v${version}")"
  else
    release_json="$(latest_stable_release)"
    version="$(jq -r '.tag_name | sub("^rust-v"; "")' <<<"$release_json")"
  fi

  [[ -n "$version" && "$version" != "null" ]] || fail "could not determine the upstream version"
  [[ "$(jq -r '.draft or .prerelease' <<<"$release_json")" == "false" ]] \
    || fail "rust-v${version} is not a stable release"

  printf 'Current version: %s\nLatest version:  %s\n' "$current_version" "$version"
  if [[ "$current_version" == "$version" ]]; then
    printf 'Already up to date.\n'
    exit 0
  fi

  x86_hash="$(to_sri "$(asset_digest "$release_json" "codex-x86_64-unknown-linux-musl.tar.gz")")"
  arm64_hash="$(to_sri "$(asset_digest "$release_json" "codex-aarch64-unknown-linux-musl.tar.gz")")"
  x86_host_hash="$(to_sri "$(asset_digest "$release_json" "codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz")")"
  arm64_host_hash="$(to_sri "$(asset_digest "$release_json" "codex-code-mode-host-aarch64-unknown-linux-musl.tar.gz")")"

  sed -i \
    -e "s|^  version = \"${current_version}\";|  version = \"${version}\";|" \
    -e "/x86_64-linux = {/,/};/ s|^      hash = .*|      hash = \"${x86_hash}\";|" \
    -e "/x86_64-linux = {/,/};/ s|^      codeModeHostHash = .*|      codeModeHostHash = \"${x86_host_hash}\";|" \
    -e "/aarch64-linux = {/,/};/ s|^      hash = .*|      hash = \"${arm64_hash}\";|" \
    -e "/aarch64-linux = {/,/};/ s|^      codeModeHostHash = .*|      codeModeHostHash = \"${arm64_host_hash}\";|" \
    packages/codex.nix

  sed -i \
    -e "s|releases/tag/rust-v${current_version}|releases/tag/rust-v${version}|g" \
    -e "s|codex-${current_version}|codex-${version}|g" \
    -e "s|Codex ${current_version}|Codex ${version}|g" \
    -e "s|./scripts/update.sh ${current_version}|./scripts/update.sh ${version}|g" \
    README.md

  nix fmt
  nix flake check --print-build-logs
  nix build .#codex --print-build-logs
  test -x result/bin/codex || fail "built package does not contain an executable bin/codex"
  test -x result/bin/codex-code-mode-host \
    || fail "built package does not contain an executable bin/codex-code-mode-host"

  printf 'Updated Codex from %s to %s.\n' "$current_version" "$version"
}

main "$@"
