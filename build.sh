#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_path="$project_dir/ControlWake.xcodeproj"
derived_data_path="$project_dir/DerivedData"
configuration="${CONFIGURATION:-Debug}"

usage() {
    printf 'Usage: %s\n' "$(basename "$0")"
    printf '\n'
    printf 'Builds the ControlWake app using the signing settings in the Xcode project.\n'
    printf 'The script only creates the app artifact; it does not install or launch it.\n'
}

if [[ "$#" -gt 0 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    printf 'error: xcodebuild was not found. Install Xcode and select it with xcode-select.\n' >&2
    exit 1
fi

printf 'Building ControlWake (%s)...\n' "$configuration"
xcodebuild \
    -project "$project_path" \
    -scheme ControlWake \
    -configuration "$configuration" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data_path" \
    -allowProvisioningUpdates \
    build

app_path="$derived_data_path/Build/Products/$configuration/ControlWake.app"
if [[ ! -d "$app_path" ]]; then
    printf 'error: build succeeded but the app was not found at %s\n' "$app_path" >&2
    exit 1
fi

app_info="$app_path/Contents/Info.plist"
extension_path="$app_path/Contents/PlugIns/ControlWakeExtension.appex"
extension_info="$extension_path/Contents/Info.plist"

app_version="$(plutil -extract CFBundleVersion raw "$app_info")"
extension_version="$(plutil -extract CFBundleVersion raw "$extension_info")"

if [[ "$app_version" != "$extension_version" ]]; then
    printf 'error: app build version %s does not match extension build version %s.\n' \
        "$app_version" "$extension_version" >&2
    exit 1
fi

printf '\nBuilt app: %s\n' "$app_path"
printf 'Build version: %s\n' "$app_version"
printf 'The app was not installed or launched.\n'
