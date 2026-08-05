#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
destination_dir=${1:-"${project_root}/dist"}
app_path="${destination_dir}/CodexSpeed.app"

mkdir -p "${destination_dir}"
swift build --package-path "${project_root}" -c release
binary_dir=$(swift build --package-path "${project_root}" -c release --show-bin-path)

if [[ -e "${app_path}" ]]; then
    rm -R "${app_path}"
fi

mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"
cp "${binary_dir}/CodexSpeed" "${app_path}/Contents/MacOS/CodexSpeed"
cp "${project_root}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
cp "${project_root}/LICENSE" "${app_path}/Contents/Resources/LICENSE"
chmod 755 "${app_path}/Contents/MacOS/CodexSpeed"
xattr -cr "${app_path}"
codesign --force --deep --sign - "${app_path}"

echo "Packaged ${app_path}"
