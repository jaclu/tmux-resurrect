#!/usr/bin/env bash

# This script shows tmux spinner with a message. It is intended to be running
# as a background process which should be `kill`ed at the end.
#
# Example usage:
#
#   ./tmux_spinner.sh "Working..." "End message!" &
#   SPINNER_PID=$!
#   ..
#   .. execute commands here
#   ..
#   kill $SPINNER_PID # Stops spinner and displays 'End message!'

#
#  I use an env var TMUX_BIN to point at the used tmux, defined in my
#  tmux.conf, in order to pick the version matching the server running,
#  or when the tmux bin is in fact tmate :)
#  If not found, it is set to whatever is in PATH, so should have no negative
#  impact. In all calls to tmux I use $TMUX_BIN instead in the rest of this
#  plugin.
#
[ -z "$TMUX_BIN" ] && TMUX_BIN="tmux"


MESSAGE="$1"
END_MESSAGE="$2"
SPIN='-\|/'

trap "$TMUX_BIN display-message '$END_MESSAGE'; exit" SIGINT SIGTERM

main() {
	local i=0
	while true; do
	  i=$(( (i+1) %4 ))
	  $TMUX_BIN display-message " ${SPIN:$i:1} $MESSAGE"
	  sleep 0.1
	done
}
main
