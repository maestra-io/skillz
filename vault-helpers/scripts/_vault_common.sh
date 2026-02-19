#!/bin/bash
# Shared library for Vault helper scripts (sourced, never executed directly)
# Provides: vault_require_jq, vault_init, vault_clean_db_name, vault_resolve_path

_VAULT_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

vault_require_jq() {
	if ! command -v jq > /dev/null 2>&1; then
		echo "Error: jq is required" >&2
		return 1
	fi
}

# vault_init <env_name>
# Resolves environment, loads per-env token, checks authentication.
# Sets VAULT_ADDR, VAULT_TOKEN, ENV_NAME, etc. in caller's scope.
vault_init() {
	local env_name="$1"
	if [ -z "$env_name" ]; then
		echo "Error: Environment name required" >&2
		return 1
	fi

	local env_exports
	if ! env_exports="$("$_VAULT_COMMON_DIR/resolve_env.sh" "$env_name")"; then
		echo "Error: Failed to resolve environment '$env_name'" >&2
		return 1
	fi
	eval "$env_exports"

	chmod 700 "$HOME/.vault-tokens" 2>/dev/null || true
	local token_file="$HOME/.vault-tokens/$env_name"
	if [ -f "$token_file" ]; then
		VAULT_TOKEN=$(cat "$token_file")
		export VAULT_TOKEN
	else
		echo "Error: No cached token for $env_name (run: vault_login.sh $env_name)" >&2
		return 1
	fi

	if ! vault token lookup > /dev/null 2>&1; then
		echo "Error: Not authenticated to Vault ($VAULT_ADDR)" >&2
		echo "Run: $_VAULT_COMMON_DIR/vault_login.sh $env_name" >&2
		return 1
	fi
}

# vault_clean_db_name <db_name> → stdout
# Strips db- prefix and known domain suffixes.
vault_clean_db_name() {
	local name="$1"
	name="${name#db-}"
	name="${name%.teleport.maestra.io}"
	name="${name%.corp.itcd.ru}"
	echo "$name"
}

# vault_resolve_path <env_name> <db_name_clean> <path_builder_fn>
# Tries exact match, env-suffixed variants, then fuzzy search.
# Calls path_builder_fn <prefix> <name_variant> to construct each Vault path.
# Sets VAULT_RESULT (JSON) and VAULT_RESOLVED_PATH in caller's scope.
vault_resolve_path() {
	local env_name="$1"
	local db_name_clean="$2"
	local path_builder_fn="$3"

	local env_suffixes=()
	case "$env_name" in
		staging) env_suffixes=("-staging") ;;
		prod)    env_suffixes=("-stable" "-beta") ;;
		sigma)   env_suffixes=("-sigma") ;;
		maestra) env_suffixes=("-omega" "-stable") ;;
	esac

	local tried_paths=()
	VAULT_RESULT=""
	VAULT_RESOLVED_PATH=""

	for name_variant in "$db_name_clean" "${env_suffixes[@]/#/$db_name_clean}"; do
		for prefix in cdp-database database; do
			local vault_path
			vault_path=$("$path_builder_fn" "$prefix" "$name_variant")
			tried_paths+=("$vault_path")
			VAULT_RESULT=$(vault read -format=json "$vault_path" 2>/dev/null) && {
				VAULT_RESOLVED_PATH="$vault_path"
				return 0
			}
			VAULT_RESULT=""
		done
	done

	# Fallback: fuzzy search via vault list
	echo "Exact match not found, searching..." >&2
	local matches=()
	for prefix in cdp-database database; do
		local list
		list=$(vault list -format=json "$prefix/config" 2>/dev/null) || continue
		while IFS= read -r entry; do
			[ -n "$entry" ] && matches+=("$prefix ${entry#db-}")
		done < <(echo "$list" | jq -r '.[]' | python3 -c "
import sys
terms = sys.argv[1].lower().split('-')
for line in sys.stdin:
    e = line.strip().lower()
    if all(t in e for t in terms):
        print(line.strip())
" "$db_name_clean")
	done

	if [ "${#matches[@]}" -eq 1 ]; then
		local match_prefix match_name vault_path
		match_prefix=$(echo "${matches[0]}" | awk '{print $1}')
		match_name=$(echo "${matches[0]}" | awk '{print $2}')
		vault_path=$("$path_builder_fn" "$match_prefix" "$match_name")
		echo "Found: $match_prefix/config/db-$match_name -> $vault_path" >&2
		VAULT_RESULT=$(vault read -format=json "$vault_path" 2>/dev/null) && {
			VAULT_RESOLVED_PATH="$vault_path"
			return 0
		}
	elif [ "${#matches[@]}" -gt 1 ]; then
		echo "Error: Multiple matches found for '$db_name_clean':" >&2
		for m in "${matches[@]}"; do
			echo "  $(echo "$m" | awk '{print $1}')/config/db-$(echo "$m" | awk '{print $2}')" >&2
		done
		echo "Please specify the exact name." >&2
		return 1
	fi

	echo "Error: Failed to read from Vault" >&2
	echo "Tried paths:" >&2
	for p in "${tried_paths[@]}"; do echo "  $p" >&2; done
	return 1
}
