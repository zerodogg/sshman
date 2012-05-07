#!/bin/csh
set DN=`dirname $0`
if(-e $DN/99sshman.sh) then
	sh $DN/99sshman.sh
else
	sh /etc/profile.d/99sshman.sh
endif
source ~/.sshman/sourceme.csh
