#!/bin/sh
printf '\033c\033]0;%s\a' prosjekt kristiania
base_path="$(dirname "$(realpath "$0")")"
"$base_path/prosjekt kristiania.x86_64" "$@"
