#!/usr/bin/env bash

set -euo pipefail

RELEASES="https://releases.crossplane.io"
TOOL_NAME="crossplane"
EXECUTABLE_NAME="crossplane"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_all_versions() {
  curl "${curl_opts[@]}" 'https://s3-us-west-2.amazonaws.com/crossplane.releases?delimiter=/&prefix=stable/' |
    grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' |
    sed 's/v//g' |
    sort -t "." -k1,1n -k2,2n -k3,3n
}

detect_system() {
  case $(uname -s) in
    Darwin) echo "darwin" ;;
    *) echo "linux" ;;
  esac
}

detect_architecture() {
  case $(uname -m) in
    x86_64 | amd64) echo "amd64" ;;
    arm64 | aarch64) echo "arm64" ;;
    *) fail "Architecture not supported" ;;

  esac
}

download_release() {
  local version platform filename url
  version="$1"
  platform="$2"
  filename="$3"

  url="$RELEASES/stable/v${version}/bin/${platform}/$TOOL_NAME"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path/bin"
    chmod +x "$ASDF_DOWNLOAD_PATH"/*
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path/bin"

    test -x "$install_path/bin/$EXECUTABLE_NAME" || fail "Expected $EXECUTABLE_NAME to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
