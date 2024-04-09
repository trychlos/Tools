#!/bin/ksh
# @(#) Configuration Management Database
#
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
# cmdb.sh specifics.
#    This command relies on the CMDBLDAP service.
#
# pwi 1998-10-21 creation
# pwi 2001-10-17 removing GEDTOOL variable
# pwi 2002- 1-18 port to CITI Exploitation Aix
# pwi 2006-10-27 tools become The Tools Project, released under GPL
# pwi 2012- 7-12 migrate to Tools v2
# pwi 2017- 6-21 publish the release at last 
# pwi 2021- 5-21 create cmdb.sh 

ttpf_main "${0}" "${@}"
