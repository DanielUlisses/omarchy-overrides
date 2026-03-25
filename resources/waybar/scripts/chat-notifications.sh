#!/usr/bin/env bash

set -euo pipefail

if ! command -v busctl >/dev/null 2>&1; then
  echo '{"text":"","class":"empty"}'
  exit 0
fi

get_registered_notifier_items() {
  local raw
  raw="$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null || true)"
  awk -F'"' '
      NF >= 2 {
        for (i = 2; i <= NF; i += 2) {
          if (index($i, "/") > 0) {
            print $i
          }
        }
      }
    ' <<< "${raw}"
}

get_notifier_names() {
  local pattern="$1"
  local raw
  raw="$(busctl --user list 2>/dev/null || true)"
  awk -v p="${pattern}" '$0 ~ p {print $1}' <<< "${raw}"
}

get_string_property() {
  local name="$1"
  local path="$2"
  local prop="$3"
  local raw
  raw="$(busctl --user get-property "${name}" "${path}" org.kde.StatusNotifierItem "${prop}" 2>/dev/null || true)"
  awk -F'"' 'NF >= 2 { print $2; exit }' <<< "${raw}"
}

get_tooltip_text() {
  local name="$1"
  local path="$2"
  local raw
  raw="$(busctl --user get-property "${name}" "${path}" org.kde.StatusNotifierItem ToolTip 2>/dev/null || true)"
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

item_matches_app() {
  local app="$1"
  local name="${2,,}"
  local id="${3,,}"
  local title="${4,,}"
  local path="${5,,}"
  local haystack="${name} ${id} ${title} ${path}"

  case "${app}" in
    slack)
      [[ "${haystack}" =~ slack ]]
      ;;
    teams)
      [[ "${haystack}" =~ teams-for-linux|microsoft-teams|microsoft[[:space:]]+teams ]]
      ;;
    *)
      return 1
      ;;
  esac
}

status_has_unread() {
  local status="${1,,}"
  [[ -z "${status}" ]] && return 1
  [[ "${status}" =~ needsattention|attention ]]
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

detect_app_unread_from_registered_items() {
  local app="$1"
  local item service path id title status tooltip fallback_tooltip remainder
  fallback_tooltip=""

  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue

    service="${item%%/*}"
    remainder="${item#*/}"
    if [[ -z "${service}" || "${service}" == "${item}" || -z "${remainder}" ]]; then
      continue
    fi

    path="/${remainder}"
    id="$(get_string_property "${service}" "${path}" "Id")"
    title="$(get_string_property "${service}" "${path}" "Title")"
    status="$(get_string_property "${service}" "${path}" "Status")"
    tooltip="$(get_tooltip_text "${service}" "${path}")"
    if [[ -z "${tooltip}" ]]; then
      tooltip="${title}"
    fi
    tooltip="${tooltip//$'\t'/ }"
    tooltip="${tooltip//$'\n'/ }"

    if ! item_matches_app "${app}" "${service}" "${id}" "${title}" "${path}"; then
      continue
    fi

    if [[ -n "${tooltip}" && ${#tooltip} -gt ${#fallback_tooltip} ]]; then
      fallback_tooltip="${tooltip}"
    fi

    if status_has_unread "${status}" || tooltip_has_unread "${app}" "${tooltip}"; then
      printf '1\t%s\n' "${tooltip}"
      return 0
    fi
  done < <(get_registered_notifier_items)

  printf '0\t%s\n' "${fallback_tooltip}"
}

detect_app_unread_from_legacy_names() {
  local pattern="$1"
  local app="$2"
  local name id tooltip fallback_tooltip
  fallback_tooltip=""

  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    id="$(get_string_property "${name}" "/StatusNotifierItem" "Id")"
    [[ -z "${id}" ]] && continue

    tooltip="$(get_tooltip_text "${name}" "/StatusNotifierItem")"
    if [[ -z "${tooltip}" ]]; then
      tooltip="$(get_string_property "${name}" "/StatusNotifierItem" "Title")"
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

detect_app_unread() {
  local app="$1"
  local pattern="$2"
  local registered_active registered_tooltip legacy_active legacy_tooltip
  registered_active=0
  registered_tooltip=""
  legacy_active=0
  legacy_tooltip=""

  IFS=$'\t' read -r registered_active registered_tooltip < <(detect_app_unread_from_registered_items "${app}")
  if (( registered_active > 0 )); then
    printf '1\t%s\n' "${registered_tooltip}"
    return 0
  fi

  IFS=$'\t' read -r legacy_active legacy_tooltip < <(detect_app_unread_from_legacy_names "${pattern}" "${app}")
  if (( legacy_active > 0 )); then
    printf '1\t%s\n' "${legacy_tooltip}"
    return 0
  fi

  if [[ -n "${registered_tooltip}" && ${#registered_tooltip} -ge ${#legacy_tooltip} ]]; then
    printf '0\t%s\n' "${registered_tooltip}"
  else
    printf '0\t%s\n' "${legacy_tooltip}"
  fi
}

get_slack_unread_from_state() {
  local slack_state_path="${HOME}/.config/Slack/storage/root-state.json"
  if [[ ! -f "${slack_state_path}" || ! -r "${slack_state_path}" ]] || ! command -v python3 >/dev/null 2>&1; then
    echo "0"
    return 0
  fi

  python3 - "${slack_state_path}" <<'PY' 2>/dev/null || echo "0"
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
try:
    obj = json.loads(path.read_text())
except Exception:
    print(0)
    raise SystemExit(0)

teams = ((obj.get("webapp") or {}).get("teams") or {})
total = 0
for team in teams.values():
    unreads = team.get("unreads") or {}
    total += int(unreads.get("unreads") or 0)
    total += int(unreads.get("unreadHighlights") or 0)

print(total)
PY
}

get_mako_active_count() {
  local app="$1"
  local regex raw

  if ! command -v makoctl >/dev/null 2>&1; then
    echo "0"
    return 0
  fi

  raw="$(makoctl list 2>/dev/null || true)"
  [[ -z "${raw}" ]] && {
    echo "0"
    return 0
  }

  case "${app}" in
    slack)
      regex='slack'
      ;;
    teams)
      regex='teams-for-linux|microsoft-teams|microsoft teams'
      ;;
    *)
      echo "0"
      return 0
      ;;
  esac

  awk -v r="${regex}" '
      BEGIN { count = 0 }
      {
        line = tolower($0)
        if (line ~ /^[[:space:]]*app name:[[:space:]]*/) {
          sub(/^[[:space:]]*app name:[[:space:]]*/, "", line)
          if (line ~ r) {
            count += 1
          }
        }
      }
      END { print count + 0 }
    ' <<< "${raw}"
}

get_waybar_env_var() {
  local var_name="$1"
  local waybar_pid env_file raw

  waybar_pid="$(pgrep -n waybar 2>/dev/null || true)"
  [[ -z "${waybar_pid}" ]] && return 1

  env_file="/proc/${waybar_pid}/environ"
  [[ ! -r "${env_file}" ]] && return 1

  raw="$(tr '\0' '\n' < "${env_file}" | awk -F= -v key="${var_name}" '$1 == key { print substr($0, index($0, "=") + 1); exit }')"
  [[ -z "${raw}" ]] && return 1

  printf '%s' "${raw}"
}

get_hyprland_window_title() {
  local app="$1"
  local hypr_sig xdg_runtime wayland_display regex

  if ! command -v hyprctl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    echo ""
    return 0
  fi

  hypr_sig="$(get_waybar_env_var "HYPRLAND_INSTANCE_SIGNATURE" || true)"
  xdg_runtime="$(get_waybar_env_var "XDG_RUNTIME_DIR" || true)"
  wayland_display="$(get_waybar_env_var "WAYLAND_DISPLAY" || true)"

  [[ -z "${hypr_sig}" || -z "${xdg_runtime}" || -z "${wayland_display}" ]] && {
    echo ""
    return 0
  }

  case "${app}" in
    slack)
      regex='slack'
      ;;
    teams)
      regex='teams-for-linux|microsoft[[:space:]]+teams|teams'
      ;;
    *)
      echo ""
      return 0
      ;;
  esac

  env HYPRLAND_INSTANCE_SIGNATURE="${hypr_sig}" XDG_RUNTIME_DIR="${xdg_runtime}" WAYLAND_DISPLAY="${wayland_display}" \
    hyprctl clients -j 2>/dev/null | python3 -c '
import json
import re
import sys

pattern = re.compile(sys.argv[1], re.I)

try:
    clients = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

for client in clients:
    cls = client.get("class") or ""
    title = client.get("title") or ""
    if pattern.search(cls) or pattern.search(title):
        print(title.strip())
        raise SystemExit(0)

print("")
' "${regex}" 2>/dev/null || echo ""
}

extract_unread_from_title() {
  local title="$1"
  local lower="${title,,}"

  [[ -z "${lower}" ]] && return 1

  if [[ "${lower}" =~ \(([1-9][0-9]*)\) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "${lower}" =~ (^|[^0-9])([1-9][0-9]*)[[:space:]]*(unread|new|notification|notifications|message|messages|activity) ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "${value}"
}

IFS=$'\t' read -r slack_active slack_tooltip < <(detect_app_unread "slack" "slack")
IFS=$'\t' read -r teams_active teams_tooltip < <(detect_app_unread "teams" "teams-for-linux|microsoft-teams|microsoft teams")

if (( slack_active == 0 )); then
  slack_state_count="$(get_slack_unread_from_state)"
  if [[ "${slack_state_count}" =~ ^[0-9]+$ && "${slack_state_count}" != "0" ]]; then
    slack_active=1
    slack_tooltip="${slack_state_count} unread"
  fi
fi

if (( slack_active == 0 )); then
  slack_popup_count="$(get_mako_active_count "slack")"
  if [[ "${slack_popup_count}" =~ ^[0-9]+$ && "${slack_popup_count}" != "0" ]]; then
    slack_active=1
    slack_tooltip="${slack_popup_count} notification"
  fi
fi

if (( teams_active == 0 )); then
  teams_popup_count="$(get_mako_active_count "teams")"
  if [[ "${teams_popup_count}" =~ ^[0-9]+$ && "${teams_popup_count}" != "0" ]]; then
    teams_active=1
    teams_tooltip="${teams_popup_count} notification"
  fi
fi

if (( teams_active == 0 )); then
  teams_window_title="$(get_hyprland_window_title "teams")"
  if teams_title_count="$(extract_unread_from_title "${teams_window_title}")"; then
    teams_active=1
    teams_tooltip="${teams_title_count} unread"
  fi
fi

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
