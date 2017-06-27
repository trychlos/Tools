# @(#) purge files from a directory
#
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
# pwi 2017- 6-27 creation

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
dir=</path/to/dir>		directory to be examined
prefix=<prefix>      	prefix of the files to be examined
generations=<count>		count of generations to be kept
update=<count>			count of last-update days to be kept
recurse					recursively delete sub-directories
"
#verbs       display list of verbs (requires --commands)
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments if any
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
	opt_dummy_def="yes"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# a directory must be specified, and exist
	if [ -z "${opt_dir}" ]; then
		msgerr "'--dir' option is mandatory, has not been found"
		let _ret+=1
	elif [ ! -d "${opt_dir}" ]; then
		msgerr "${opt_dir}: directory not found or not readable"
		let _ret+=1
	fi

	# a prefix should have been specified, unless *all* files of this
	#  same directory be managed
	if [ -z "${opt_prefix}" ]; then
		msgwarn "'--prefix' option should be specified unless all files of the directory are managed"
	fi 

	# one of --generations or --days must be specified
	typeset -i _action=0
	[ "${opt_generations_set}" = "yes" ] && let _action+=1
	[ "${opt_update_set}" = "yes" ] && let _action+=1
	if [ ${_action} -ne 1 ]; then
		msgerr "one of '--generations' or '--update' option must be specified"
		let _ret+=1

	elif [ "${opt_generations_set}" = "yes" ]; then
		if [ ${opt_generations} -lt 1 ]; then
			msgerr "at least one generation of files should be kept, '${opt_generations}' found"
			let _ret+=1
		fi

	elif [ "${opt_update_set}" = "yes" ]; then
		if [ ${opt_update} -lt 1 ]; then
			msgerr "at least one update old of files should be kept, '${opt_update}' found"
			let _ret+=1
		fi
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# force the delete to be printed (the 'rm' to be verbose)

function verb_main {
	#set -x
	typeset -i _ret=0

	typeset _rmverb=""
	#[ "${opt_verbose}" = "yes" ] && _rmverb="v"
	_rmverb="v"

	typeset _rmrec=""
	[ "${opt_recurse}" = "yes" ] && _rmrec="r"

	# keep a count of generations of the files, regarding their dates
	if [ "${opt_generations_set}" = "yes" ]; then
		typeset _cmd="/bin/ls -1t ${opt_dir}/${opt_prefix}* 2>/dev/null \
						| awk -v max=${opt_generations} '{ i+=1; if( i>max ) print }' \
						| xargs -r -n1 rm -${_rmverb}${_rmrec}f"
		execDummy "${_cmd}"

	# keep count days old of the files, depending of their last update time
	# doesn't follow symbolic links
	elif [ "${opt_update_set}" = "yes" ]; then
		typeset _cmd="find -P "${opt_dir}" -name '${opt_prefix}*' -mtime +${opt_update} 2>/dev/null \
						| xargs -r -n1 rm -${_rmverb}${_rmrec}f"
		execDummy "${_cmd}"

	fi

	return ${_ret}
}
