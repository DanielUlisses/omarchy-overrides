#!/usr/bin/env bash

# Recreate ~/repos/<client>/<repo> from installations/repos.tsv (written by
# bin/repos-snapshot on the other machine): client folders, clone, working branch,
# extra remotes (fork upstreams) and the per-repo user.email client repos need.
# Repos already present are left alone, so it is safe to rerun after fixing SSH access.
#
# Needs SSH access to GitHub and Azure DevOps (ssh.dev.azure.com) working first.

set -euo pipefail

REPOS_ROOT="${REPOS_ROOT:-$HOME/repos}"
MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repos.tsv"

# First contact with github.com / ssh.dev.azure.com would otherwise stop at the host-key prompt.
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}"

failed=()

while IFS=$'\t' read -r rel origin branch extra email; do
  [[ -z "$rel" || "$rel" == \#* ]] && continue
  dest="$REPOS_ROOT/$rel"

  if [ -e "$dest" ]; then
    echo "Keeping existing $dest"
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  echo "==> Cloning $rel"
  if ! git clone --quiet "$origin" "$dest"; then
    failed+=("$rel (clone)")
    continue
  fi

  if [ "$extra" != "-" ]; then
    IFS=, read -ra remotes <<<"$extra"
    for remote in "${remotes[@]}"; do
      git -C "$dest" remote add "${remote%%=*}" "${remote#*=}"
    done
  fi

  [ "$email" = "-" ] || git -C "$dest" config user.email "$email"

  if [ "$branch" != "-" ] && [ "$(git -C "$dest" branch --show-current)" != "$branch" ]; then
    if git -C "$dest" fetch --quiet origin "$branch" 2>/dev/null; then
      git -C "$dest" checkout --quiet -B "$branch" --track "origin/$branch"
    else
      failed+=("$rel (branch $branch is not on origin, stayed on default)")
    fi
  fi
done <"$MANIFEST"

if [ ${#failed[@]} -gt 0 ]; then
  echo "Needs attention:" >&2
  printf '  %s\n' "${failed[@]}" >&2
  exit 1
fi

echo "Repos cloned into $REPOS_ROOT."
