#!/usr/bin/env bash

set -euo pipefail

if ! command -v busctl >/dev/null 2>&1; then
  echo '{"text":"","class":"empty"}'
  exit 0
fi

get_notifier_names() {
  local pattern="$1"
  local raw
  raw="$(busctl --user list 2>/dev/null || true)"
  awk -v p="${pattern}" '$0 ~ p {print $1}' <<< "${raw}"
}

get_string_property() {
  local name="$1"
  local prop="$2"
  local raw
  raw="$(busctl --user get-property "${name}" /StatusNotifierItem org.kde.StatusNotifierItem "${prop}" 2>/dev/null || true)"
  awk -F'"' 'NF >= 2 { print $2; exit }' <<< "${raw}"
}

get_tooltip_text() {
  local name="$1"
  local raw
  raw="$(busctl --user get-property "${name}" /StatusNotifierItem org.kde.StatusNotifierItem ToolTip 2>/dev/null || true)"
  awk -F'"' '
      BEGIN { best = "" }
      {
        for (i = 2; i <= NF; i += 2) {
          if (length($i) > length(best)) {
            best = $i
          }
        }
      }
      END { print best }
    ' <<< "${raw}"
}

tooltip_has_unread() {
  local app="$1"
  local tooltip="${2,,}"
  [[ -z "${tooltip}" ]] && return 1

  if [[ "${tooltip}" =~ no[[:space:]]+unread|0[[:space:]]+unread|no[[:space:]]+new[[:space:]]+messages|nothing[[:space:]]+new ]]; then
    return 1
  fi

  case "${app}" in
    slack)
      [[ "${tooltip}" =~ ^slack$ ]] && return 1
      ;;
    teams)
      [[ "${tooltip}" =~ ^microsoft[[:space:]]+teams$|^teams[[:space:]]+for[[:space:]]+linux$ ]] && return 1
      ;;
  esac

  if [[ "${tooltip}" =~ \([1-9][0-9]*\) ]]; then
    return 0
  fi

  if [[ "${tooltip}" =~ [1-9][0-9]*[[:space:]]*(unread|new|notification|notifications|message|messages|activity) ]]; then
    return 0
  fi

  if [[ "${tooltip}" =~ unread|new[[:space:]]+messages|new[[:space:]]+activity ]]; then
    return 0
  fi

  return 1
}

extract_unread_count() {
  local tooltip="${1,,}"

  if [[ "${tooltip}" =~ \(([1-9][0-9]*)\) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "${tooltip}" =~ ([1-9][0-9]*)[[:space:]]*(unread|new|notification|notifications|message|messages|activity) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

detect_app_unread() {
  local pattern="$1"
  local app="$2"
  local name id tooltip fallback_tooltip
  fallback_tooltip=""

  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    id="$(get_string_property "${name}" "Id")"
    [[ -z "${id}" ]] && continue

    tooltip="$(get_tooltip_text "${name}")"
    if [[ -z "${tooltip}" ]]; then
      tooltip="$(get_string_property "${name}" "Title")"
    fi
    tooltip="${tooltip//$'\t'/ }"
    tooltip="${tooltip//$'\n'/ }"

    if [[ -n "${tooltip}" && ${#tooltip} -gt ${#fallback_tooltip} ]]; then
      fallback_tooltip="${tooltip}"
    fi

    if tooltip_has_unread "${app}" "${tooltip}"; then
      printf '1\t%s\n' "${tooltip}"
      return 0
    fi
  done < <(get_notifier_names "${pattern}")

  printf '0\t%s\n' "${fallback_tooltip}"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "${value}"
}

IFS=$'\t' read -r slack_active slack_tooltip < <(detect_app_unread "slack" "slack")
IFS=$'\t' read -r teams_active teams_tooltip < <(detect_app_unread "teams-for-linux|microsoft-teams|microsoft teams" "teams")

if (( slack_active == 0 && teams_active == 0 )); then
  echo '{"text":"","class":"empty"}'
  exit 0
fi

text=""
tooltip_parts=()

if (( slack_active > 0 )); then
  text=""
  if slack_count="$(extract_unread_count "${slack_tooltip}")"; then
    tooltip_parts+=("Slack: ${slack_count}")
  else
    tooltip_parts+=("Slack: unread")
  fi
fi

if (( teams_active > 0 )); then
  if [[ -n "${text}" ]]; then
    text="${text} "
  fi
  text="${text}󰊻"
  if teams_count="$(extract_unread_count "${teams_tooltip}")"; then
    tooltip_parts+=("Teams for Linux: ${teams_count}")
  else
    tooltip_parts+=("Teams for Linux: unread")
  fi
fi

if (( ${#tooltip_parts[@]} == 1 )); then
  tooltip="Unread notifications (${tooltip_parts[0]})"
else
  tooltip="Unread notifications (${tooltip_parts[0]}, ${tooltip_parts[1]})"
fi

printf '{"text":"%s","tooltip":"%s","class":"active"}\n' "$(json_escape "${text}")" "$(json_escape "${tooltip}")"
