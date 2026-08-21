#!/usr/bin/env bash
# Copies src_dir to dest_dir, then replaces every literal occurrence of
# old_name with new_name in every file under dest_dir (skipping .git).
#
# Used for both:
#   - copying service-template into a new service repo — dest_dir MAY
#     already exist here (see "merge mode" below): the target GitHub
#     repo is often already created and cloned empty before this script
#     runs, since init-service requires the repo to pre-exist.
#   - copying prod-setup/services/service-template into a new
#     prod-setup/services/<name> subdirectory — dest_dir must NOT
#     already exist here; it's a plain subdirectory of an existing repo,
#     not its own git repo, so there's no "merge mode" to detect.
#
# Merge mode: if dest_dir already exists AND contains a .git directory,
# this treats it as an already-cloned (likely near-empty) target repo
# instead of refusing. It copies every entry from src_dir into dest_dir,
# dotfiles included, overwriting any same-named file/dir already present
# in dest_dir — EXCEPT:
#   - dest_dir/.git is never touched (it's the real history + remote,
#     already set up by the caller).
#   - dest_dir/.idea is left alone if it already exists (machine-local
#     IDE config the user may have already set up for that directory;
#     not part of the template's "correctness").
# If dest_dir exists but has no .git, that's an unrelated directory
# collision, not a mergeable target — this still refuses, same as
# before.
#
# Usage: copy-and-rename.sh <src_dir> <dest_dir> <old_name> <new_name>
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <src_dir> <dest_dir> <old_name> <new_name>" >&2
  exit 1
fi

src_dir="$1"
dest_dir="$2"
old_name="$3"
new_name="$4"

if [ ! -d "$src_dir" ]; then
  echo "error: source directory does not exist: $src_dir" >&2
  exit 1
fi

if [ -e "$dest_dir" ]; then
  if [ ! -d "$dest_dir/.git" ]; then
    echo "error: destination already exists and is not a git repo, refusing to overwrite: $dest_dir" >&2
    exit 1
  fi

  echo "destination already exists as a git repo — merging $src_dir into it: $dest_dir"
  shopt -s dotglob
  for entry in "$src_dir"/*; do
    base=$(basename "$entry")
    if [ "$base" = ".git" ]; then
      continue
    fi
    if [ "$base" = ".idea" ] && [ -e "$dest_dir/.idea" ]; then
      echo "  skipping .idea (destination already has one)"
      continue
    fi
    rm -rf "${dest_dir:?}/${base:?}"
    cp -r "$entry" "$dest_dir/$base"
  done
  shopt -u dotglob
else
  cp -r "$src_dir" "$dest_dir"
  rm -rf "$dest_dir/.git"
fi

# perl -pi (not sed -i) so this behaves the same on macOS (BSD sed) and
# Linux (GNU sed) without a portability shim for the -i flag.
grep -rlF -- "$old_name" "$dest_dir" | while IFS= read -r f; do
  perl -pi -e "s/\Q${old_name}\E/${new_name}/g" "$f"
done

echo "Copied $src_dir -> $dest_dir, replaced '$old_name' with '$new_name'"
