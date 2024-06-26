if [ -d "$HOME/.tmux/resurrect" ]; then
        default_resurrect_dir="$HOME/.tmux/resurrect"
else
        default_resurrect_dir="${XDG_DATA_HOME:-$HOME/.local/share}"/tmux/resurrect
fi
resurrect_dir_option="@resurrect-dir"

SUPPORTED_VERSION="1.9"
RESURRECT_FILE_PREFIX="tmux_resurrect"
RESURRECT_FILE_EXTENSION="txt"
_RESURRECT_DIR=""
_RESURRECT_FILE_PATH=""

d=$'\t'



#
#  I use an env var TMUX_BIN to point at the used tmux, defined in my
#  tmux.conf, in order to pick the version matching the server running,
#  or when the tmux bin is in fact tmate :)
#  If not found, it is set to whatever is in PATH, so should have no negative
#  impact. In all calls to tmux I use $TMUX_BIN instead in the rest of this
#  plugin.
#
[ -z "$TMUX_BIN" ] && TMUX_BIN="tmux"


my_helpers_log() {
	echo "scripts/helpers.$1" >> /tmp/resurrect.log
}


# helper functions
get_tmux_option() {
	my_helpers_log "get_tmux_option  [$1] [$2]"
	local option="$1"
	local default_value="$2"
	local option_value=$($TMUX_BIN show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# Ensures a message is displayed for 5 seconds in tmux prompt.
# Does not override the 'display-time' tmux option.
display_message() {
	my_helpers_log "display_message [$1] [$2]"
	local message="$1"

	# display_duration defaults to 5 seconds, if not passed as an argument
	if [ "$#" -eq 2 ]; then
		local display_duration="$2"
	else
		local display_duration="5000"
	fi

	# saves user-set 'display-time' option
	local saved_display_time=$(get_tmux_option "display-time" "750")

	# sets message display time to 5 seconds
	$TMUX_BIN set-option -gq display-time "$display_duration"

	# displays message
	$TMUX_BIN display-message "$message"

	# restores original 'display-time' value
	$TMUX_BIN set-option -gq display-time "$saved_display_time"
}


supported_tmux_version_ok() {
	my_helpers_log supported_tmux_version_ok
	$CURRENT_DIR/check_tmux_version.sh "$SUPPORTED_VERSION"
}

remove_first_char() {
	my_helpers_log "remove_first_char [$1]"
	echo "$1" | cut -c2-
}

capture_pane_contents_option_on() {
	my_helpers_log capture_pane_contents_option_on
	local option="$(get_tmux_option "$pane_contents_option" "off")"
	[ "$option" == "on" ]
}

files_differ() {
	my_helpers_log "files_differ  [$1] [$2]"
	! cmp -s "$1" "$2"
}

get_grouped_sessions() {
	my_helpers_log "get_grouped_sessions [$1]"
	local grouped_sessions_dump="$1"
	export GROUPED_SESSIONS="${d}$(echo "$grouped_sessions_dump" | cut -f2 -d"$d" | tr "\\n" "$d")"
}

is_session_grouped() {
	my_helpers_log "is_session_grouped ses_name=[$1]"
	local session_name="$1"
	[[ "$GROUPED_SESSIONS" == *"${d}${session_name}${d}"* ]]
}

# pane content file helpers

pane_contents_create_archive() {
	my_helpers_log pane_contents_create_archive
	tar cf - -C "$(resurrect_dir)/save/" ./pane_contents/ |
		gzip > "$(pane_contents_archive_file)"
}

pane_content_files_restore_from_archive() {
	my_helpers_log pane_content_files_restore_from_archive
	local archive_file="$(pane_contents_archive_file)"
	if [ -f "$archive_file" ]; then
		mkdir -p "$(pane_contents_dir "restore")"
		gzip -d < "$archive_file" |
			tar xf - -C "$(resurrect_dir)/restore/"
	fi
}

# path helpers

resurrect_dir() {
	my_helpers_log resurrect_dir
	if [ -z "$_RESURRECT_DIR" ]; then
		local path="$(get_tmux_option "$resurrect_dir_option" "$default_resurrect_dir")"
		# expands tilde, $HOME and $HOSTNAME if used in @resurrect-dir
		echo "$path" | sed "s,\$HOME,$HOME,g; s,\$HOSTNAME,$(hostname),g; s,\~,$HOME,g"
	else
		echo "$_RESURRECT_DIR"
	fi
}
_RESURRECT_DIR="$(resurrect_dir)"

resurrect_file_path() {
	my_helpers_log resurrect_file_path
	if [ -z "$_RESURRECT_FILE_PATH" ]; then
		local timestamp="$(date +"%Y%m%dT%H%M%S")"
		echo "$(resurrect_dir)/${RESURRECT_FILE_PREFIX}_${timestamp}.${RESURRECT_FILE_EXTENSION}"
	else
		echo "$_RESURRECT_FILE_PATH"
	fi
}
_RESURRECT_FILE_PATH="$(resurrect_file_path)"

last_resurrect_file() {
	my_helpers_log last_resurrect_file
	echo "$(resurrect_dir)/last"
}

pane_contents_dir() {
	my_helpers_log "pane_contents_dir [$1]"
	echo "$(resurrect_dir)/$1/pane_contents/"
}

pane_contents_file() {
	my_helpers_log "pane_contents_file [$1] [$2]"
	local save_or_restore="$1"
	local pane_id="$2"
	echo "$(pane_contents_dir "$save_or_restore")/pane-${pane_id}"
}

pane_contents_file_exists() {
	my_helpers_log "pane_contents_file_exists [$1]"
	local pane_id="$1"
	[ -f "$(pane_contents_file "restore" "$pane_id")" ]
}

pane_contents_archive_file() {
	my_helpers_log pane_contents_archive_file
	echo "$(resurrect_dir)/pane_contents.tar.gz"
}

execute_hook() {
	my_helpers_log "execute_hook [$1]"
	local kind="$1"
	shift
	local args="" hook=""

	hook=$(get_tmux_option "$hook_prefix$kind" "")

	# If there are any args, pass them to the hook (in a way that preserves/copes
	# with spaces and unusual characters.
	if [ "$#" -gt 0 ]; then
		printf -v args "%q " "$@"
	fi

	if [ -n "$hook" ]; then
		eval "$hook $args"
	fi
}
