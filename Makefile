# SSHMan makefile

VERSION=0.1.2

install:
	mkdir -p "$(prefix)/etc/profile.d/"
	cp 99sshman.sh "$(prefix)/etc/profile.d/"
	cp 99sshman.csh "$(prefix)/etc/profile.d/"
	[ -d "$(prefix)"/etc/X11/Xsession.d ] && ln -sf "$(prefix)/etc/profile.d/99sshman."* "$(prefix)"/etc/X11/Xsession.d || true
	chmod 744 "$(prefix)/etc/profile.d/99sshman.sh"
uninstall:
	rm -f "$(prefix)/etc/profile.d/99sshman.sh"
	rm -f "$(prefix)/etc/profile.d/99sshman.csh"
clean:
	rm -f *~
	rm -f sshman-$(VERSION).tar.bz2
	rm -rf sshman-$(VERSION)
distrib: clean
	mkdir -p sshman-$(VERSION)
	for file in `find . -type f|grep -v svn|grep -v tar|grep -v swp`; do cp $$file ./sshman-$(VERSION);done
	tar -jcvf sshman-$(VERSION).tar.bz2 ./sshman-$(VERSION)
	rm -rf sshman-$(VERSION)
