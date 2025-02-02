# @(#) dump the last commit(s) of the named SVN repository
#
# -@(@) This script makes direct file access to SVN repository files
# -@(@) (though through regular svn tools), and must be executed locally
# -@(@) on the SVN box.
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
#   Last commit is identified from 'last previously saved commit + 1'
#   until current HEAD.
#
# pwi 2002- 7-11 creation
# pwi 2013- 6- 7 move into TTP from svn-dump-repo.sh
# pwi 2013- 6-25 update to new automatic command-line interpretation
# pwi 2013- 7-18 review options dynamic computing
# pwi 2013- 7-27 fix #14 using csv output of svn.sh list
# pwi 2017- 6-21 publish the release at last
# pwi 2021- 9- 4 make sure the group is able to access the output file
# pwi 2021-12-16 fix repository name

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
dummy					dummy execution
verbose					verbose execution
service=<identifier>	service identifier
repository=<name>		repository name
dumpdir=<path>      	dump directory
since=<first>       	the first revision to dump
"
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments if any
#  first word is the name of the argument
#  rest of line is the help message
#
#function verb_arg_define_pos {
#	echo "
#repo				svn repository name
#"
#}

# ---------------------------------------------------------------------
# initialize specific default values

function verb_arg_set_defaults {
	opt_dummy_def="yes"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# the service mnemonic is mandatory
	if [ -z "${opt_service}" ]; then
		msgErr "service identifier is mandatory, has not been found"
		let _ret+=1
	fi

	# a repository name must be specified
	if [ -z "${opt_repository}" ]; then
		msgErr "repository name is mandatory, has not been found"
		let _ret+=1
	fi

	# if specified, the first revision to be dumped must be > 1
	if [ ! -z "${opt_since}" ]; then
		if [ ${opt_since} -lt 1 ]; then
			msgErr "first revision to be dumped must be greater than 0, found ${opt_since}"
			let _ret+=1
		fi
	fi

	# checks for repository vars (name, dir, ...) and for svn binaries
	#  (svnadmin, ...) are delayed until having first check that we are
	#  running on the correct node

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# check which node hosts the required service
	typeset _node="$(tabGetNode "${opt_service}")"
	if [ -z "${_node}" ]; then
		msgErr "'${opt_service}': no hosting node found (environment='${ttp_node_environment}')"
		let _ret+=1

	elif [ "${_node}" != "${TTP_NODE}" ]; then
		typeset _parms="$@"
		execRemote "${_node}" "${ttp_command} ${ttp_verb} ${_parms}" 
		return $?

	# we are on the right node
	else
		# we do not need a special account here as long as the current one
		# has permissions to execute the svnadmin binary
		svnadmin --version 1>/dev/null 2>&1
		if [ $? -ne 0 ]; then
			msgErr "'svnadmin': not found or not available"
			let _ret+=1

		else
			typeset _repodir="$(svnGetRepoPath "${opt_service}" "${opt_repository}")"
			if [ -z "${_repodir}" ]; then
				msgErr "'${opt_repository}': unknown repository name"
				let _ret+=1

			else
				typeset _head=$(svnGetRepoHead "${opt_service}" "${opt_repository}")

				# get the default dest dump path if not specified as an option
				#  making sure that destination directory exists
				typeset _destdir="${opt_dumpdir}"
				[ -z "${_destdir}" ] &&
					_destdir="$(confGetKey "ttp_node_keys" "${opt_service}" "0=dumpdir" 1 | \
						tabSubstituteMacro "" "@R" "" "${opt_repository}")"
				execDummy "mkdir -p -m 0775 '${_destdir}'"
		
				# get last revision previously saved
				typeset -i _last=0
				if [ ! -z "${opt_since}" ]; then
					_last=${opt_since}-1
				else
					typeset _lastf="$(basename \
										$(\ls -1rt ${_destdir}/svn-*.tar.gz 2>/dev/null | \
											tail -1 | \
											sed 's?\.tar\.gz??') 2>/dev/null)"
					if [ ! -z "${_lastf}" ]; then
						_last=$(echo "${_lastf}" | cut -d- -f3)
					fi
				fi
		
				# save from next revision after last
				typeset -i _first=1+${_last}
		
				# save until head
				#  do not save if there is no new revision
				if [ ${_first} -le ${_head} ]; then
					typeset _destfile="${_destdir}/svn-${_first}-${_head}.tar.gz"
					msgOut "dumping new revisions into ${_destfile}"
					execDummy "svnadmin dump --revision ${_first}:${_head} --incremental ${_repodir} | gzip > '${_destfile}'"
				else
					msgOut "${opt_repository}: last saved was ${_last}, head is ${_head}: nothing to dump"
				fi
			fi
		fi
	fi
}
