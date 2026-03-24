#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

SOURCE_SCRIPT="${REPO_ROOT}/resources/waybar/scripts/chat-notifications.sh"
TARGET_SCRIPT="${HOME}/.config/waybar/scripts/chat-notifications.sh"
TARGET_CONFIG="${HOME}/.config/waybar/config.jsonc"
TARGET_STYLE="${HOME}/.config/waybar/style.css"

if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
  echo "Missing source script: ${SOURCE_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${TARGET_CONFIG}" ]]; then
  echo "Missing Waybar config: ${TARGET_CONFIG}" >&2
  exit 1
fi

if [[ ! -f "${TARGET_STYLE}" ]]; then
  echo "Missing Waybar style: ${TARGET_STYLE}" >&2
  exit 1
fi

mkdir -p "$(dirname "${TARGET_SCRIPT}")"
install -m 755 "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"

python - "${TARGET_CONFIG}" "${TARGET_SCRIPT}" <<'PY'
from pathlib import Path
import sys

config_path = Path(sys.argv[1])
exec_path = sys.argv[2]
text = config_path.read_text()

def find_array_bounds(source: str, key: str) -> tuple[int, int]:
    key_pos = source.find(key)
    if key_pos == -1:
        raise SystemExit(f"Could not find {key} in {config_path}")
    left_bracket = source.find("[", key_pos)
    if left_bracket == -1:
        raise SystemExit(f"Could not find '[' for {key} in {config_path}")

    depth = 0
    right_bracket = -1
    for idx in range(left_bracket, len(source)):
        ch = source[idx]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                right_bracket = idx
                break

    if right_bracket == -1:
        raise SystemExit(f"Could not find matching ']' for {key} in {config_path}")

    return left_bracket, right_bracket

def ensure_modules_center(source: str) -> tuple[str, bool]:
    left, right = find_array_bounds(source, '"modules-center"')
    block = source[left:right + 1]

    if '"custom/chat-notifications"' in block:
        return source, False

    insertion = '    "custom/chat-notifications",\n'
    clock_pos = block.find('"clock"')

    if clock_pos != -1:
        line_end = block.find("\n", clock_pos)
        if line_end == -1:
            line_end = len(block) - 1
        block = block[: line_end + 1] + insertion + block[line_end + 1 :]
    else:
        close_pos = block.rfind("]")
        if close_pos == -1:
            raise SystemExit(f"Invalid modules-center block in {config_path}")

        body = block[:close_pos]
        scan = len(body) - 1
        while scan >= 0 and body[scan].isspace():
            scan -= 1

        if scan >= 0 and body[scan] not in "[,":
            body = body[: scan + 1] + "," + body[scan + 1 :]

        block = body + insertion + block[close_pos:]

    return source[:left] + block + source[right + 1 :], True

def ensure_chat_module(source: str) -> tuple[str, bool]:
    if '"custom/chat-notifications": {' in source:
        return source, False

    module_block = (
        '  "custom/chat-notifications": {\n'
        f'    "exec": "{exec_path}",\n'
        '    "return-type": "json",\n'
        '    "interval": 3\n'
        '  },\n'
    )

    anchor = source.find('  "network": {')
    if anchor != -1:
        return source[:anchor] + module_block + source[anchor:], True

    final_brace = source.rfind("}")
    if final_brace == -1:
        raise SystemExit(f"Invalid JSON object in {config_path}")

    prefix = source[:final_brace].rstrip()
    if not prefix.endswith(","):
        prefix += ","
    prefix += "\n"
    return prefix + module_block + source[final_brace:], True

text, changed_center = ensure_modules_center(text)
text, changed_module = ensure_chat_module(text)

if changed_center or changed_module:
    config_path.write_text(text)
    print("Updated Waybar config.jsonc")
else:
    print("Waybar config.jsonc already up to date")
PY

python - "${TARGET_STYLE}" <<'PY'
from pathlib import Path
import sys

style_path = Path(sys.argv[1])
text = style_path.read_text()

if "#custom-chat-notifications {" in text:
    print("Waybar style.css already up to date")
    raise SystemExit(0)

style_block = (
    "\n#custom-chat-notifications {\n"
    "  min-width: 12px;\n"
    "  margin-left: 8px;\n"
    "}\n\n"
    "#custom-chat-notifications.empty {\n"
    "  margin-left: 0;\n"
    "}\n"
)

clock_anchor = "#clock {"
anchor_pos = text.find(clock_anchor)

if anchor_pos != -1:
    clock_end = text.find("}\n", anchor_pos)
    if clock_end != -1:
        insert_pos = clock_end + 2
        text = text[:insert_pos] + style_block + text[insert_pos:]
    else:
        text = text.rstrip() + style_block + "\n"
else:
    text = text.rstrip() + style_block + "\n"

style_path.write_text(text)
print("Updated Waybar style.css")
PY

if command -v omarchy-restart-waybar >/dev/null 2>&1; then
  omarchy-restart-waybar
  echo "Installed chat notifications module and restarted Waybar."
else
  echo "Installed chat notifications module."
  echo "Run omarchy-restart-waybar to apply changes."
fi
