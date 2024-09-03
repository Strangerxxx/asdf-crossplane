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

version_weight () {
  echo -e "$1" | tr ' ' "\n"  | sed -e 's:\+.*$::' | sed -e 's:^v::' | \
    sed -re 's:^[0-9]+(\.[0-9]+)+$:&-stable:' | \
    sed -re 's:([^A-Za-z])dev\.?([^A-Za-z]|$):\1.10.\2:g' | \
    sed -re 's:([^A-Za-z])(alpha|a)\.?([^A-Za-z]|$):\1.20.\3:g' | \
    sed -re 's:([^A-Za-z])(beta|b)\.?([^A-Za-z]|$):\1.30.\3:g' | \
    sed -re 's:([^A-Za-z])(rc|RC)\.?([^A-Za-z]|$)?:\1.40.\3:g' | \
    sed -re 's:([^A-Za-z])stable\.?([^A-Za-z]|$):\1.50.\2:g' | \
    sed -re 's:([^A-Za-z])pl\.?([^A-Za-z]|$):\1.60.\2:g' | \
    sed -re 's:([^A-Za-z])(patch|p)\.?([^A-Za-z]|$):\1.70.\3:g' | \
    sed -r 's:\.{2,}:.:' | \
    sed -r 's:\.$::' | \
    sed -r 's:-\.:.:'
}

list_all_versions() {
  local versions_list tags_orig tags_weight keys ix

  versions_list=$(curl "${curl_opts[@]}" 'https://s3-us-west-2.amazonaws.com/crossplane.releases?delimiter=/&prefix=stable/' |
  grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z.0-9]+)?' |
  sed 's/v//g')


  mapfile -t tags_orig <<< "${versions_list}"
  mapfile -t tags_weight <<< "$(version_weight "${tags_orig[*]}")"

  keys=$(for ix in ${!tags_weight[*]}; do
      printf "%s+%s\n" "${tags_weight[${ix}]}" "${ix}"
  done | sort -V | cut -d+ -f2)

  for ix in ${keys}; do
      printf "%s\n" "${tags_orig[${ix}]}"
  done
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
