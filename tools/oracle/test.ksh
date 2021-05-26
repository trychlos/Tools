# @(#) test running services
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
# Synopsis:
#
#   Anyone is able to check for Oracle services (not only the Oracle
#   software owner), though we require for now to be logged in locally
#   on the Oracle server.
#
# sc  2001- 4-20 creation
# jcl 2001- 5-18 test for archivelog mode
# raj 2002-12- 4 port to Gec environment, test for instance
# pwi 2002-12-27 test for listener
# pwi 2003- 3- 6 distinguish between listener and instance return codes
# pwi 2003- 3-20 accept several archiver processes
# pwi 2003- 3-25 trap interrupts and delete temp files
# gma 2003-10- 1 make optional the connection test
# gma 2004- 2-23 directly ask the listener for its status
# gma 2004- 3-29 fix the listener test
# jcl 2004- 7-30 add traces
# gmi 2006- 8- 3 fix archivelog mode test
# pwi 2006-10-27 the tools become The Tools Project, released under GPL
# pwi 2013- 6-10 migrate to command-line dynamic interpretation scheme
# pwi 2013- 7-18 review options dynamic computing
# pwi 2017- 6-21 publish the release at last 

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help					display this online help and gracefully exit
service=<identifier>	service identifier
listener				test the listener status
instance				test the instance status
processes				test the presence of the instance processes
connect					test the database connectivity
archiver				check the archiver process 
"
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments
#  first word is the name of the argument
#  rest of line is the help message
#
#function verb_arg_define_pos {
#	echo "
#"
#}

# ---------------------------------------------------------------------
# initialize specific default values

function verb_arg_set_defaults {
	opt_processes_def="yes"
	opt_connect_def="yes"
	opt_archiver_def="yes"
}

# ---------------------------------------------------------------------

function verb_arg_check {
	#set -x
	typeset -i _ret=0

	# the service mnemonic is mandatory
	if [ -z "${opt_service}" ]; then
		msgerr "service mnemonic is mandatory, was not found"
		let _ret+=1
	fi

	# at least one option must be specified
	if [ "${opt_listener}" = "no" -a \
			"${opt_instance}" = "no" ]; then
				msgerr "no valid option found, at least one is mandatory"
				let _ret+=1
	fi

	# archivelog mode can only be checked when testing the DB instance
	# connection can only be checked when testing a DB instance
	#   but these are boolean values which default to 'yes'
	#   we so just cannot see if they have been specified

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	typeset -i _ret=0

	# check which machine hosts the required service
	typeset _host="$(tabGetMachine "${opt_service}")"

	if [ -z "${_host}" ]; then
		msgerr "'${opt_service}': unknown service mnemonic"
		let _ret+=1

	# we require to be locally logged in on the Oracle server
	# but don't have any prerequisites against the user itself
	elif [ "${_host}" != "${ttp_logical}" ]; then
		typeset _parms="$@"
		execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}"
		let _ret+=$?

	else
		# this machine hosts the required service

		#set | grep -e '^opt_'

		# test for the listener status
		if [ "${opt_listener}" = "yes" ]; then
			oraTestListener "${opt_service}"
			let _ret+=$?
		fi

		# test for the database instance processes
		#  we are testing here only for some well-identified processes
		if [ "${opt_instance}" = "yes" ]; then

			# test the instance processes
			if [ ${_ret} -eq 0 -a "${opt_processes}" = "yes" ]; then
				oraTestDBInstance "${opt_service}"
				let _ret+=$?
			fi

			# try to connect to database
			if [ ${_ret} -eq 0 -a "${opt_connect}" = "yes" ]; then
				msgout "connecting to the database..." "" " "
				typeset _version="$(oracle.sh info -service "${opt_service}" -version -metrics | \
									grep 'Oracle Database' | \
									sed -e 's/^.*;\(.*\);\(.*\);.*$/\1 version \2/')"
				if [ -z "${_version}" ]; then
					msgout "NOT OK" " \b"
					let _ret=1
				else
					msgout "OK: ${_version}" " \b"
				fi
			fi
		fi
	fi

	return ${_ret}
}
