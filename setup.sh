#!/bin/sh
# setup.sh: one-time contributor setup, run from this BG3Tools checkout (Git Bash on Windows works).
#   1. clones LootAdvisor and BuildAdvisor next to BG3Tools when they are missing (the tools find each other as
#      siblings: <folder>/BG3Tools, <folder>/LootAdvisor, <folder>/BuildAdvisor),
#   2. points each of the three repos at the shared pre-push hook in BG3Tools/hooks (core.hooksPath), unless that repo
#      already uses another hooks path (left alone; pass --force to replace it).
# Safe to run again. Undo the hook: git -C <repo> config --unset core.hooksPath
set -eu
force=no; [ "${1:-}" = "--force" ] && force=yes
here=$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })
parent=$(dirname "$here")
for r in LootAdvisor BuildAdvisor; do
  if [ -e "$parent/$r/.git" ]; then echo "$r: already at $parent/$r"
  else git clone "https://github.com/md12ol/$r.git" "$parent/$r"; fi
done
for r in BG3Tools LootAdvisor BuildAdvisor; do
  cur=$(git -C "$parent/$r" config --get core.hooksPath || true)
  if [ -n "$cur" ] && [ "$cur" != "$here/hooks" ] && [ "$force" = no ]; then
    echo "$r: keeps its hooks path $cur (--force replaces it)"
  else
    git -C "$parent/$r" config core.hooksPath "$here/hooks"
    echo "$r: pre-push hook = $here/hooks/pre-push"
  fi
done
echo "Next: pip install lz4 zstandard pillow lupa, then see CONTRIBUTING.md (build, install, test in the game)."
