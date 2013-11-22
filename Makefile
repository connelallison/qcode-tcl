NAME=qcode
VERSION=2.03
PACKAGEDIR=tcl
TESTDIR=test
MAINTAINER=hackers@qcode.co.uk
RELEASE=$(shell cat RELEASE)
REMOTEUSER=debian.qcode.co.uk
REMOTEHOST=debian.qcode.co.uk
REMOTEDIR=debian.qcode.co.uk

.PHONY: all test

all: test package upload clean incr-release
package: set-version
	checkinstall -D --deldoc --backup=no --install=no --pkgname=$(NAME)-$(VERSION) --pkgversion=$(VERSION) --pkgrelease=$(RELEASE) -A all -y --maintainer $(MAINTAINER) --pkglicense="BSD" --reset-uids=yes --requires "tcl8.5,tcllib,qcode-doc,html2text,curl,tclcurl" --replaces none --conflicts none make install

test:   set-version
	./pkg_mkIndex $(PACKAGEDIR)
	tclsh ./test_all.tcl -testdir $(TESTDIR)

install: set-version
	./set-version-number.tcl ${VERSION}
	./pkg_mkIndex $(PACKAGEDIR)
	mkdir -p /usr/lib/tcltk/$(NAME)$(VERSION)
	cp $(PACKAGEDIR)/*.tcl /usr/lib/tcltk/$(NAME)$(VERSION)/
	cp LICENSE /usr/lib/tcltk/$(NAME)$(VERSION)/

upload:
	scp $(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb "$(REMOTEUSER)@$(REMOTEHOST):$(REMOTEDIR)/debs"	
	ssh $(REMOTEUSER)@$(REMOTEHOST) reprepro -b $(REMOTEDIR) includedeb squeeze $(REMOTEDIR)/debs/$(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb
	ssh $(REMOTEUSER)@$(REMOTEHOST) reprepro -b $(REMOTEDIR) includedeb wheezy $(REMOTEDIR)/debs/$(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb

clean:
	rm $(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb

incr-release:
	./incr-release-number.tcl

set-version:
	./set-version-number.tcl ${VERSION}
	RELEASE=$(shell cat RELEASE)	

uninstall:
	rm -r /usr/lib/tcltk/$(NAME)$(VERSION)
