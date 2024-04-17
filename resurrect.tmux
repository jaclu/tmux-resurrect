#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/variables.sh"
source "$CURRENT_DIR/scripts/helpers.sh"


get_bind_note() {
    local vers_running="$($TMUX_BIN -V | tr -dC '[:digit:]')"

    #
    #  Generic plugin setting I use to add Notes to plugin keys that are bound
    #  This makes this key binding show up when doing <prefix> ?
    #  If not set to "Yes", no attempt at adding notes will happen.
    #  bind-key Notes were added in tmux 3.1, so should not be used on older
    #  versions!
    #
    if [[ "$(get_tmux_option "@use_bind_key_notes_in_plugins" "No")" = "Yes" ]] \
           && [[ "$vers_running" -ge 31 ]]; then
        echo "-N plugin\ tmux-resurrect"
    fi
}

set_save_bindings() {
	local key_bindings=$(get_tmux_option "$save_option" "$default_save_key")
	local key
	local bind_note="$(get_bind_note)"
	for key in $key_bindings; do
		[[ -n "$bind_note" ]] && bind_note="${bind_note}\ -\ save"
		eval $TMUX_BIN bind-key "$bind_note" "$key" run-shell "$CURRENT_DIR/scripts/save.sh"
	done
}

set_restore_bindings() {
	local key_bindings=$(get_tmux_option "$restore_option" "$default_restore_key")
	local key
	local bind_note="$(get_bind_note)"
	for key in $key_bindings; do
		[[ -n "$bind_note" ]] && bind_note="${bind_note}\ -\ restore"
		eval $TMUX_BIN bind-key "$bind_note" "$key" run-shell "$CURRENT_DIR/scripts/restore.sh"
	done
}

set_default_strategies() {
	$TMUX_BIN set-option -gq "${restore_process_strategy_option}irb" "default_strategy"
	$TMUX_BIN set-option -gq "${restore_process_strategy_option}mosh-client" "default_strategy"
}

set_script_path_options() {
	$TMUX_BIN set-option -gq "$save_path_option" "$CURRENT_DIR/scripts/save.sh"
	$TMUX_BIN set-option -gq "$restore_path_option" "$CURRENT_DIR/scripts/restore.sh"
}

main() {
    set_save_bindings
    set_restore_bindings
    set_default_strategies
    set_script_path_options
}
main
