#!/usr/bin/env bash
# Copies src_dir to dest_dir, then replaces every literal occurrence of
# old_name with new_name in every file under dest_dir (skipping .git).
#
# Used for both:
#   - copying service-template into a new service repo
#   - copying prod-setup/services/service-template into a new
#     prod-setup/services/<name> subdirectory
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
  echo "error: destination already exists, refusing to overwrite: $dest_dir" >&2
  exit 1
fi

cp -r "$src_dir" "$dest_dir"
rm -rf "$dest_dir/.git"

# perl -pi (not sed -i) so this behaves the same on macOS (BSD sed) and
# Linux (GNU sed) without a portability shim for the -i flag.
grep -rlF -- "$old_name" "$dest_dir" | while IFS= read -r f; do
  perl -pi -e "s/\Q${old_name}\E/${new_name}/g" "$f"
done

echo "Copied $src_dir -> $dest_dir, replaced '$old_name' with '$new_name'"
