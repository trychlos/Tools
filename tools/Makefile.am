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
#
# Authors:
#   Pierre Wieser <pwieser@trychlos.org>

toolsdir = $(exec_prefix)/tools

# despite the '-type f', we also get the subdirectories
FILES = $(patsubst $(srcdir)/%,%,$(shell find $(srcdir) -type f -name 'Makefile.*' -prune -o -print))

install-data-hook:
	@let -i _count=0; \
	for f in $(FILES); do \
		if test -d $(srcdir)/$$f; then continue; fi; \
		d=$${f%/*}; \
		if test "$$d" = "$$f"; then d=""; fi; \
		b=$${f##*/}; \
		if test "$$b" = "tools"; then continue; fi; \
		if ! test -d $(DESTDIR)$(toolsdir)/$$d; then $(MKDIR_P) -m 0775 -v $(DESTDIR)$(toolsdir)/$$d; fi; \
		$(INSTALL) -m 0664 $(srcdir)/$$f $(DESTDIR)$(toolsdir)/$$d/$$b; \
		let _count+=1; \
	done; \
	chmod 0775 $(DESTDIR)$(toolsdir)/bin/*; \
	echo "[Tools/tools] $$_count installed files"

uninstall-local:
	rm -fr $(DESTDIR)$(toolsdir)
