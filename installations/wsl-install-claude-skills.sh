#!/usr/bin/env bash

# Claude Code plus every skill the Omarchy machine has, into ~/.claude and each claude-acc
# account (~/.claude-switch/accounts/<name>). Rerun after `claude-acc add <name>` so the new
# account gets them too.
#
# Run installations/wsl-clone-repos.sh first: ticket, ead, humanizer and devops-blog-post
# install from the clones under ~/repos/daniel.
#
# Skills that come with the claude.ai login (anthropic-skills, engineering, operations)
# sync by themselves and are not handled here.

set -euo pipefail

REPOS_ROOT="${REPOS_ROOT:-$HOME/repos}"
OMARCHY_PATH="${OMARCHY_PATH:-$([ -d /usr/share/omarchy ] && echo /usr/share/omarchy || echo "$HOME/.local/share/omarchy")}"

# claude and npx come from mise (node is set up by wsl-setup-shell.sh).
eval "$(mise activate bash --shims)"
command -v claude >/dev/null || mise use -g claude@latest

ROOTS=("$HOME/.claude")
for account in "$HOME"/.claude-switch/accounts/*/; do
  [ -d "$account" ] && ROOTS+=("${account%/}")
done

# Symlink a skill into every root. A real directory already there is kept, never replaced.
link_skill() {
  local name="$1" src="$2" root dest
  if [ ! -d "$src" ]; then
    echo "WARNING: $src not found, skipping skill $name" >&2
    return
  fi
  for root in "${ROOTS[@]}"; do
    dest="$root/skills/$name"
    mkdir -p "$root/skills"
    if [ "$dest" -ef "$src" ]; then
      continue
    elif [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "Keeping existing $dest"
    else
      ln -snf "$src" "$dest"
    fi
  done
}

echo "==> mattpocock-skills plugin"
for root in "${ROOTS[@]}"; do
  # ~/.claude is the default config dir; setting CLAUDE_CONFIG_DIR to it would move .claude.json.
  if [ "$root" = "$HOME/.claude" ]; then cfg=(env -u CLAUDE_CONFIG_DIR); else cfg=(env CLAUDE_CONFIG_DIR="$root"); fi
  "${cfg[@]}" claude plugin marketplace list 2>/dev/null | grep -q 'claude-plugins-official' ||
    "${cfg[@]}" claude plugin marketplace add anthropics/claude-plugins-official
  "${cfg[@]}" claude plugin list 2>/dev/null | grep -q 'mattpocock-skills@claude-plugins-official' ||
    "${cfg[@]}" claude plugin install mattpocock-skills@claude-plugins-official --scope user
done

echo "==> Skills from the open skills registry (skills.sh)"
# The skills CLI installs into ~/.claude/skills (or ~/.agents/skills when other agents are
# picked too); the claude-acc accounts get a link to that copy.
npx -y skills add herdrdev/herdr --skill herdr -g -y -a claude-code
npx -y skills add vercel-labs/skills --skill find-skills -g -y -a claude-code
for skill in herdr find-skills; do
  src="$HOME/.agents/skills/$skill"
  [ -d "$src" ] || src="$HOME/.claude/skills/$skill"
  link_skill "$skill" "$src"
done

echo "==> Omarchy skills"
link_skill omarchy "$OMARCHY_PATH/default/agents/skills/omarchy"
link_skill diagnose-crash "$OMARCHY_PATH/default/agents/skills/diagnose-crash"

echo "==> Own skills from ~/repos/daniel"
# ticket-skill copies (it has its own installer, and keeps a hand-edited ticket-models.env).
if [ -x "$REPOS_ROOT/daniel/ticket-skill/install.sh" ]; then
  "$REPOS_ROOT/daniel/ticket-skill/install.sh" "${ROOTS[@]}"
else
  echo "WARNING: $REPOS_ROOT/daniel/ticket-skill not cloned, skipping the ticket skills" >&2
fi
# The rest are linked, so a git pull in the repo updates the skill.
link_skill ead "$REPOS_ROOT/daniel/ead-skill"
link_skill humanizer "$REPOS_ROOT/daniel/humanizer-skill"
link_skill devops-blog-post "$REPOS_ROOT/daniel/UlissesTech/.claude/skills/devops-blog-post"

echo "Claude skills installed into: ${ROOTS[*]}"
