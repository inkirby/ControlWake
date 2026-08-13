#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
configuration="${CONFIGURATION:-Release}"
source_app="${1:-$project_dir/DerivedData/Build/Products/$configuration/ControlWake.app}"
destination_app="/Applications/ControlWake.app"
expected_app_id="com.inkirby.ControlWake"
expected_extension_id="com.inkirby.ControlWake.ControlWakeExtension"

usage() {
    printf 'Usage: %s [path-to-ControlWake.app]\n' "$(basename "$0")"
    printf '\n'
    printf 'Installs an existing ControlWake build into /Applications.\n'
    printf 'When no path is supplied, the Release build artifact is used.\n'
}

if [[ "$#" -gt 1 ]]; then
    usage >&2
    exit 2
fi

if [[ "$#" -eq 1 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
    esac
fi

if [[ ! -d "$source_app" ]]; then
    printf 'error: app was not found at %s\n' "$source_app" >&2
    printf 'Build it first with: CONFIGURATION=%s ./build.sh\n' "$configuration" >&2
    exit 1
fi

source_app="$(cd "$(dirname "$source_app")" && pwd)/$(basename "$source_app")"
app_info="$source_app/Contents/Info.plist"
extension_path="$source_app/Contents/PlugIns/ControlWakeExtension.appex"
extension_info="$extension_path/Contents/Info.plist"

if [[ ! -f "$app_info" || ! -f "$extension_info" ]]; then
    printf 'error: app or embedded ControlWake extension is missing an Info.plist.\n' >&2
    exit 1
fi

app_id="$(plutil -extract CFBundleIdentifier raw "$app_info")"
extension_id="$(plutil -extract CFBundleIdentifier raw "$extension_info")"
app_version="$(plutil -extract CFBundleVersion raw "$app_info")"
extension_version="$(plutil -extract CFBundleVersion raw "$extension_info")"

if [[ "$app_id" != "$expected_app_id" ]]; then
    printf 'error: unexpected app bundle identifier: %s\n' "$app_id" >&2
    exit 1
fi

if [[ "$extension_id" != "$expected_extension_id" ]]; then
    printf 'error: unexpected extension bundle identifier: %s\n' "$extension_id" >&2
    exit 1
fi

if [[ "$app_version" != "$extension_version" ]]; then
    printf 'error: app build version %s does not match extension build version %s.\n' \
        "$app_version" "$extension_version" >&2
    exit 1
fi

if ! codesign --verify --deep --strict "$source_app"; then
    printf 'error: app signature verification failed.\n' >&2
    exit 1
fi

printf 'Installing ControlWake build %s...\n' "$app_version"

if pgrep -x ControlWake >/dev/null 2>&1; then
    printf 'Asking the running app to quit...\n'
    osascript -e 'tell application id "com.inkirby.ControlWake" to quit' \
        >/dev/null 2>&1 || true

    for _ in {1..50}; do
        if ! pgrep -x ControlWake >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

if pgrep -x ControlWake >/dev/null 2>&1; then
    printf 'The app did not quit in time; sending a termination signal...\n'
    pkill -x ControlWake || true

    for _ in {1..50}; do
        if ! pgrep -x ControlWake >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

if pgrep -x ControlWake >/dev/null 2>&1; then
    printf 'error: ControlWake is still running. Quit it and try again.\n' >&2
    exit 1
fi

backup_root="$(mktemp -d "${TMPDIR:-/tmp}/ControlWake-install.XXXXXX")"
backup_app="$backup_root/ControlWake.app"
previous_app_backed_up=0
copy_started=0
install_succeeded=0

cleanup() {
    status="$?"
    trap - EXIT

    if [[ "$install_succeeded" -eq 0 && "$copy_started" -eq 1 ]]; then
        rm -rf "$destination_app"
        if [[ "$previous_app_backed_up" -eq 1 && -d "$backup_app" ]]; then
            mv "$backup_app" "$destination_app"
            printf 'The previous installation was restored.\n' >&2
        fi
    fi

    rm -rf "$backup_root"
    exit "$status"
}
trap cleanup EXIT

if [[ -d "$destination_app" ]]; then
    mv "$destination_app" "$backup_app"
    previous_app_backed_up=1
fi

copy_started=1
if ! ditto "$source_app" "$destination_app"; then
    printf 'error: could not copy ControlWake to /Applications.\n' >&2
    exit 1
fi

if ! codesign --verify --deep --strict "$destination_app"; then
    printf 'error: the installed app failed signature verification.\n' >&2
    exit 1
fi

install_succeeded=1
printf 'Installed: %s\n' "$destination_app"
printf 'Open ControlWake from /Applications to start it and refresh its Control Center control.\n'
