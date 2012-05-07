#!/bin/bash
# SSHMan - a very simple ssh key manager
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Purpose: Write sourceme files
# Usage: WriteSourceMe
WriteSourceMe()
{
	echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK;export SSH_AUTH_SOCK;SSH_AGENT_PID=$SSH_AGENT_PID;export SSH_AGENT_PID" > "$HOME/.sshman/sourceme"
	echo -e "setenv SSH_AUTH_SOCK $SSH_AUTH_SOCK\nsetenv SSH_AGENT_PID $SSH_AGENT_PID" > "$HOME/.sshman/sourceme.csh"
}

# Purpose: Ensure that SSH_ASKPASS is set
# Usage: CheckSSHAskpass
CheckSSHAskpass ()
{
	[ "$SSH_ASKPASS" != "" ] && return
	if type ssh-askpass &>/dev/null; then
		SSH_ASKPASS="`which ssh-askpass`"
	elif type gnome-ssh-askpass &>/dev/null; then
		SSH_ASKPASS="`which gnome-ssh-askpass`"
	else
		for file in gnome-ssh-askpass ssh-askpass bssh-askpass qt-ssh-askpass; do
			for dir in /usr/lib/ssh /etc/alternatives; do
				if [ -x "$dir/$file" ]; then
					SSH_ASKPASS="$dir/$file"
					return
				fi
			done
		done
	fi
}

# Purpose: Check if we need to add keys, and add if needed
# Usage: CheckAddKeys
#	This function also tests for interactivity and forks if needed
CheckAddKeys () {
	# If we're not interactive (running under a terminal) then fork the
	# adding function off
	if ! perl -e 'if (-t STDIN && -t STDOUT) { exit 0 } else { exit 1 }'; then
		if [ -e "$HOME/.sshman/requireTerminal" ]; then
			return
		fi
		CheckAddKeys_REAL &
	else
		CheckAddKeys_REAL
	fi
}

# Purpose: Do the actual work for the above function
# Usage: CheckAddKeys_REAL
CheckAddKeys_REAL () {
	# Source the sourceme file to ensure we have the proper
	# agent connected
	source "$HOME/.sshman/sourceme"

	# Default is not to add
	ADD_IT=0

	# If we are being called from within an ssh session then don't add any keys
	if [ "$SSH_CLIENT" != "" ] && [ "$SSH_CONNECTION" != "" ]; then
		return
	fi

	if ! ssh-add -l &> /dev/null; then
		ADD_IT=1
	else
		if [ "`ssh-add -l |egrep '(/|@)'`" != "" ] && [ "`ssh-add -l | grep "$HOME"`" = "" ]; then
			ADD_IT=1
		fi
	fi
	
	if [ "$ADD_IT" = "1" ] && ! LockFile_Locked; then
		echo $$ > "$HOME/.sshman/adding"
		CheckSSHAskpass
		SSH_ASKPASS=$SSH_ASKPASS ssh-add
		rm -f  "$HOME/.sshman/adding"
	fi
}

# Purpose: Check if the lockfile is present
# Usage: if LockFile_Locked; then
LockFile_Locked ()
{
	if [ ! -e "$HOME/.sshman/adding" ]; then
		return 1
	fi
	CONTENTS="`cat "$HOME/.sshman/adding"`"
	if [ `uname -s` = "Linux" ]; then
		if [ "$CONTENTS" != "" ] && [ -d /proc/$CONTENTS ]; then
			return 0
		fi
	else
		return 0
	fi
	rm -f "$HOME/.sshman/adding"
	return 1
}

# Purpose: Check if we need to start a new ssh agent manager, and do it
# Usage: StartManager
StartManager () {
	# If an agent is already running then just check for adding keys (plus add it to sourceme)
	if [ "$SSH_AUTH_SOCK" != "" ] && [ -e "$SSH_AUTH_SOCK" ]; then
		# Don't handle clients that come in through ssh
		if [ "$SSH_CLIENT" != "" ] && [ "$SSH_CONNECTION" != "" ] ; then
			return
		elif [ "$SSH_AGENT_PID" != "" ]; then
			WriteSourceMe
			CheckAddKeys
			return
		fi
	fi

	# First source the source file and see if we can connect to the
	# agent. If not then continue.
	if [ -e "$HOME/.sshman/sourceme" ];then
		source "$HOME/.sshman/sourceme"
		
		if [ "$SSH_AUTH_SOCK" != "" ] && [ -e "$SSH_AUTH_SOCK" ] && [ "$SSH_AGENT_PID" != "" ] && [ -w "$SSH_AUTH_SOCK" ]; then
			# Attempt to connect
			if perl -MIO::Socket::UNIX -e 'my $Sock = IO::Socket::UNIX->new(Peer => $ENV{SSH_AUTH_SOCK}, Type => SOCK_STREAM) or exit 1;exit 0' &>/dev/null; then
				# Right, we connected. Socket and agent alive.
				# Check if we are currently adding keys, if not then do it now.
				CheckAddKeys;
	
				return
			fi
		fi
	fi
	
	# If we have reached this far and we are running under ssh then we shouldn't continue
	if [ "$SSH_CLIENT" != "" ] && [ "$SSH_CONNECTION" != "" ]; then
		return
	fi

	# Start the agent, source the file
	ssh-agent |grep -v echo &> "$HOME/.sshman/sourceme"
	source "$HOME/.sshman/sourceme"

	# (Re)-write source file (so we have the csh version aswell)
	WriteSourceMe
	# Add the keys
	CheckAddKeys
}

# Check if ~/.sshman exists, if it does then try to StartManager()
if [ -d "$HOME/.sshman/" ]; then
	StartManager
fi
