#!/usr/bin/env bash
# Installs codeburn-rs and the Noctalia plugin as pacman packages, then enables the plugin.
set -euo pipefail

PLUGIN_ID="dvaxert/codeburn"
SOURCE_NAME="codeburn"
SOURCE_PATH="/usr/share/noctalia-codeburn"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [option]

  (none)         Install codeburn-rs and the plugin, then enable the plugin
  --plugin-only  Install the plugin. codeburn-rs must already be installed
  --cli-only     Install codeburn-rs
  --uninstall    Disable the plugin and remove both packages
  -h, --help     Show this help

Set CODEBURN_RS_DIR to build codeburn-rs from an existing checkout instead of cloning it.
USAGE
}

say() {
  printf '\n==> %s\n' "$1"
}

source_location() {
  noctalia msg plugins source list 2>/dev/null | awk -v name="$SOURCE_NAME" '$1 == name { print $3 }'
}

shell_running() {
  command -v noctalia >/dev/null && noctalia msg plugins source list >/dev/null 2>&1
}

build_package() {
  local dir="$1" out="$2" deps="$3"
  (cd "$dir" && BUILDDIR="$out/build" PKGDEST="$out" makepkg "$deps" --force --clean)
}

codeburn_rs_dir() {
  local work="$1"
  if [[ -n "${CODEBURN_RS_DIR:-}" ]]; then
    printf '%s\n' "$CODEBURN_RS_DIR"
    return
  fi
  # Clone the way this repo was cloned, so SSH and HTTPS checkouts both work.
  local url
  url="$(git -C "$REPO_DIR" remote get-url origin)"
  url="${url/noctalia-codeburn/codeburn-rs}"
  git clone --quiet --depth 1 "$url" "$work/codeburn-rs"
  printf '%s\n' "$work/codeburn-rs"
}

remove_shadowing_binary() {
  # ~/.cargo/bin usually comes before /usr/bin on PATH, so an old copy would win.
  if [[ -x "$HOME/.cargo/bin/codeburn-rs" ]] && command -v cargo >/dev/null; then
    say "Removing the old cargo install, which would shadow /usr/bin/codeburn-rs"
    cargo uninstall codeburn-rs
  fi
}

enable_plugin() {
  if ! shell_running; then
    say "Noctalia is not running. Run these once it is:"
    echo "  noctalia msg plugins source add $SOURCE_NAME path $SOURCE_PATH"
    echo "  noctalia msg plugins enable $PLUGIN_ID"
    return
  fi
  say "Enabling the plugin"
  local current
  current="$(source_location)"
  if [[ -n "$current" && "$current" != "$SOURCE_PATH" ]]; then
    noctalia msg plugins disable "$PLUGIN_ID" || true
    noctalia msg plugins source remove "$SOURCE_NAME"
    current=""
  fi
  if [[ -z "$current" ]]; then
    noctalia msg plugins source add "$SOURCE_NAME" path "$SOURCE_PATH"
  fi
  # Cycling makes the shell read the new manifest and scripts.
  noctalia msg plugins disable "$PLUGIN_ID" >/dev/null 2>&1 || true
  noctalia msg plugins enable "$PLUGIN_ID"
  echo "Add the \"$PLUGIN_ID:bar\" widget in Settings -> Bar if it is not on your bar yet."
}

uninstall() {
  if shell_running; then
    say "Disabling the plugin"
    noctalia msg plugins disable "$PLUGIN_ID" || true
    if [[ "$(source_location)" == "$SOURCE_PATH" ]]; then
      noctalia msg plugins source remove "$SOURCE_NAME"
    fi
  fi
  say "Removing the packages"
  local installed=()
  for name in noctalia-codeburn codeburn-rs; do
    if pacman -Q "$name" >/dev/null 2>&1; then
      installed+=("$name")
    fi
  done
  if ((${#installed[@]} > 0)); then
    sudo pacman -R "${installed[@]}"
  fi
}

main() {
  local want_cli=1 want_plugin=1
  case "${1:-}" in
    "") ;;
    --plugin-only) want_cli=0 ;;
    --cli-only) want_plugin=0 ;;
    --uninstall)
      uninstall
      return
      ;;
    -h | --help)
      usage
      return
      ;;
    *)
      usage >&2
      return 2
      ;;
  esac

  if ! command -v makepkg >/dev/null || ! command -v pacman >/dev/null; then
    echo "install.sh needs pacman and makepkg. On other distros, see the README." >&2
    return 1
  fi
  if ((EUID == 0)); then
    echo "Run install.sh as your own user. It asks for sudo when it needs it." >&2
    return 1
  fi
  if ((want_plugin && !want_cli)) && ! pacman -Q codeburn-rs >/dev/null 2>&1; then
    echo "codeburn-rs is not installed. Run ./install.sh without --plugin-only." >&2
    return 1
  fi

  local work
  work="$(mktemp -d)"
  # Expanded now: the local is gone by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT

  if ((want_cli)); then
    say "Building codeburn-rs"
    local cli_dir
    cli_dir="$(codeburn_rs_dir "$work")"
    build_package "$cli_dir" "$work" --syncdeps
  fi
  if ((want_plugin)); then
    say "Building the plugin package"
    # codeburn-rs is not in any repo, and pacman gets both packages at once below.
    build_package "$REPO_DIR" "$work" --nodeps
  fi

  say "Installing"
  sudo pacman -U "$work"/*.pkg.tar.*

  if ((want_cli)); then
    remove_shadowing_binary
  fi
  if ((want_plugin)); then
    enable_plugin
  fi
  say "Done"
}

main "$@"
