# The Tools Project: a Tools System and Paradigm for IT Production
# Copyright (©) 2003-2021 Pierre Wieser (see AUTHORS)
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
# use: "autoreconf" to generate configure.

AC_PREREQ(2.59)

AC_INIT([Tools],[2.4.2-2021],[pwieser@trychlos.org],ttp,[])

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])
AC_CANONICAL_TARGET
AM_INIT_AUTOMAKE

# Code coverage
AX_CODE_COVERAGE()

AC_CONFIG_SRCDIR([tools/bin/ttp.sh])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([no-dist-gzip dist-xz])

AC_CONFIG_FILES([
	Makefile
	ansible/Makefile
	docs/Makefile
	maintainer/Makefile
	tools/Makefile
])

AC_OUTPUT
