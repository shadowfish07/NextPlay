#!/usr/bin/env bash

# Load repository-local NEXTPLAY_* values without executing the .env file as a
# shell script. Variables already exported by the caller take precedence.
nextplay_load_env() {
  local repo_root="$1"
  local env_file="${NEXTPLAY_ENV_FILE:-$repo_root/.env}"
  local line
  local line_number=0
  local key
  local value

  [[ -f "$env_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line%$'\r'}"

    if [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?(NEXTPLAY_[A-Z0-9_]+)[[:space:]]*=(.*)$ ]]; then
      key="${BASH_REMATCH[2]}"
      value="${BASH_REMATCH[3]}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
        value="${value:1:${#value}-2}"
      fi

      if [[ -z "${!key+x}" ]]; then
        printf -v "$key" '%s' "$value"
        export "$key"
      fi
      continue
    fi

    echo "Invalid entry in ${env_file} at line ${line_number}; only NEXTPLAY_* assignments are allowed." >&2
    return 1
  done <"$env_file"
}
