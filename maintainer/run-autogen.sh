#!/bin/sh
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
# Authors:
#   Pierre Wieser <pwieser@trychlos.org>

if [ ! -f configure.ac ]; then
	echo "> This script must be run from the top source directory." 1>&2
	exit 1
fi

maintainer_dir=$(cd ${0%/*}; pwd)
top_srcdir="${maintainer_dir%/*}"

PkgName=`autoconf --trace 'AC_INIT:$1' configure.ac`
pkgname=$(echo $PkgName | tr '[[:upper:]]' '[[:lower:]]')

# an openbook-x.y may remain after an aborted make distcheck
# such a directory breaks gnome-autogen.sh generation
# so clean it here
for d in $(find ${top_srcdir} -maxdepth 2 -type d -name "${pkgname}-*"); do
	echo "> Removing $d"
	chmod -R u+w $d
	rm -fr $d
done

REQUIRED_INTLTOOL_VERSION=0.35.5

echo "> Running aclocal"
aclocal --install || exit 1

# requires gtk-doc package
# used for Developer Reference Manual generation (devhelp)
#echo "> Running gtkdocize"
#gtkdocize || exit 1

echo "> Running autoreconf"
autoreconf --verbose --force --install -Wno-portability || exit 1

runconf="${top_srcdir}/run-configure.sh"
echo "> Generating ${runconf}"
cat <<EOF >${runconf}
#!/bin/sh
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
# Authors:
#   Pierre Wieser <pwieser@trychlos.org>
#
# WARNING
#   This file has been automatically generated by
#   ${maintainer_dir}/${0##*/}
#   on $(date).
#   It is supposed to be run from ${top_srcdir}. Please do not manually
#   modify it.

# top_srcdir here is the root of the source directory
top_srcdir="\$(cd \${0%/*}; pwd)"

# heredir is the root of the _build/_install directories
heredir=\$(pwd)

mkdir -p \${heredir}/_build
cd \${heredir}/_build

conf_cmd="../configure"
conf_args="${conf_args}"
conf_args="\${conf_args} --prefix=\${heredir}/_install"
#conf_args="\${conf_args} --enable-maintainer-mode"
#conf_args="\${conf_args} --enable-iso-c"
#conf_args="\${conf_args} --disable-as-needed"
conf_args="\${conf_args} $*"
conf_args="\${conf_args} \$*"

tput bold
echo "\${conf_cmd} \${conf_args}
"
tput sgr0

\${conf_cmd} \${conf_args}
EOF

echo "> Executing ${runconf}
"
chmod a+x ${runconf}
${runconf} &&
make -C _build &&
make -C _build install
