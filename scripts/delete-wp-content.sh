#!/usr/bin/env bash
# Usage: delete-wp-content.sh <themes|plugins|uploads|all> [--confirm]
set -euo pipefail

mode="${1:-}"
confirm_each=false

if [[ "${2:-}" == "--confirm" ]]; then
	confirm_each=true
fi

clean_dir() {
	local dir="$1"
	local label="$2"
	local keep="${3:-index.php}"
	local removed=0
	local skipped=0

	for item in "$dir"/*; do
		[[ -e "$item" ]] || continue

		local skip=false
		for keep_name in $keep; do
			if [[ "$(basename "$item")" == "$keep_name" ]]; then
				skip=true
				break
			fi
		done
		$skip && continue

		if $confirm_each; then
			local ans=""
			while true; do
				printf "Delete %s '%s'? [y/n] " "$label" "$(basename "$item")"
				read -r ans
				case "$ans" in
					[yY]) break ;;
					[nN]) echo "  Skipped."; skipped=$((skipped + 1)); ans="skip"; break ;;
					*) echo "  Enter y or n." ;;
				esac
			done
			[[ "$ans" == "skip" ]] && continue
		fi

		rm -rf "$item"
		echo "  Deleted $(basename "$item")."
		removed=$((removed + 1))
	done

	if [[ $removed -eq 0 && $skipped -eq 0 ]]; then
		echo "Nothing to delete in $dir/."
	fi
}

case "$mode" in
	themes)
		clean_dir app/themes theme
		;;
	plugins)
		clean_dir app/plugins plugin
		;;
	uploads)
		clean_dir app/uploads upload "index.php .gitkeep"
		;;
	all)
		clean_dir app/themes theme
		clean_dir app/plugins plugin
		;;
	*)
		echo "Usage: delete-wp-content.sh <themes|plugins|uploads|all> [--confirm]" >&2
		exit 1
		;;
esac
