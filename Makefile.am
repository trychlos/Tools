# The Tools Project: a Tools System and Paradigm for IT Production
# Copyright (©) 2003-2017 Pierre Wieser (see AUTHORS)
#
# The Tools Project is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# The Tools Project is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with The Tools Project; see the file COPYING. If not,
# see <http://www.gnu.org/licenses/>.

SUBDIRS = \
	docs							\
	maintainer						\
	tools							\
	$(NULL)

docdir = $(datadir)/doc/@PACKAGE@-@VERSION@

dist_doc_DATA = \
	AUTHORS ChangeLog COPYING COPYING-DOCS INSTALL NEWS README TODO

uninstall-local:
	rmdir $(DESTDIR)$(docdir)

# just run "maintainer/make_install_txz.sh" and that'll be done 
install-txz:
	make && \
	make DESTDIR=$(TMPDIR)/_install/$(PACKAGE)-$(VERSION) install && \
	cd "$(TMPDIR)/_install" && \
	tar -cvJf - * > "/tmp/$(PACKAGE)-$(VERSION)-install.tar.xz"
	@echo "==="
	@echo "=== /tmp/$(PACKAGE)-$(VERSION)-install.tar.xz available"
	@echo "==="
