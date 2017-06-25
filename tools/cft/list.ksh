# @(#) list the content of the parameters files
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
# pwi 2002- 1-23 creation
# pwi 2002- 2-15 status = ALL
# pwi 2002- 7-13 dynamically identify the CFT host
# jps 2005- 4-22 add --meters option
# pwi 2006-10-27 the tools become The Tools Project, released under GPL
# pwi 2013- 6- 4 add partner to --meters infos
# pwi 2013- 6-10 migrate to command-line dynamic interpretation scheme
# pwi 2013- 6-21 take an optional service mnemonic
# pwi 2013- 6-24 adopt the standard tabular format (aka SQL-like)
# pwi 2013- 7-18 review options dynamic computing
# pwi 2017- 6-21 publish the release at last 

disp_catalog=""
disp_format=""

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help						display this online help and gracefully exit
service=<identifier>		service identifier
all							display all parameters
general						display general parameters
partners					display partner definitions
send						display send definitions
receive						display receive definitions
logs						display log files definitions
account						display accounting files definitions
catalog[=BRIEF|FULL]		display catalog content (case insensitive)
format={CSV|RAW|TABULAR}	output format (case insensitive)
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
	opt_catalog_def="BRIEF"
	opt_format_def="TABULAR"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# the service identifier is mandatory
	if [ -z "${opt_service}" ]; then
		msgerr "service identifier is mandatory, has not been found"
		let _ret+=1
	fi

	# at least one option must be specified
	if [ "${opt_all}" = "no" -a \
			"${opt_general}" = "no" -a \
			"${opt_partner}" = "no" -a \
			"${opt_send}" = "no" -a \
			"${opt_receive}" = "no" -a \
			"${opt_logs}" = "no" -a \
			"${opt_account}" = "no" -a \
			"${opt_catalog_set}" = "no" ]; then
				msgerr "no option found, at least one is mandatory"
				let _ret+=1

	# if '--all' option is specified, then it must be the only boolean
	#  one specified
	elif [ "${opt_all}" = "yes" ]; then
		if [ "${opt_general}" = "yes" -o \
				"${opt_partner}" = "yes" -o \
				"${opt_send}" = "yes" -o \
				"${opt_receive}" = "yes" -o \
				"${opt_logs}" = "yes" -o \
				"${opt_account}" = "yes" ]; then
					msgerr "'--all' option found, no other boolean can be specified"
					let _ret+=1
		fi
	fi

	typeset _cont
	for _cont in $(echo "${opt_catalog}" | strUpper); do
		case "${_cont}" in
			B|BR|BRI|BRIE|BRIEF)
				disp_catalog="BRIEF"
				;;
			F|FU|FUL|FULL)
				disp_catalog="FULL"
				;;
			*)
				msgerr "'--catalog' option value must be 'BRIEF' or 'FULL', '${opt_catalog}' found"
				let _ret+=1
		esac
	done

	# set output format
	disp_format="$(formatCheck "${opt_format}")"
	let _ret+=$?

	return ${_ret}
}

# ---------------------------------------------------------------------
# output the raw result of the CFTUTIL LISTCAT CONTENT=FULL command
#  without any formatting

function f_listcat {
	typeset _cmd="$(confGetKey ttp_node_keys "${opt_service}" 0=listcatf 1)"
	[ -z "${_cmd}" ] && _cmd="CFTUTIL LISTCAT CONTENT=${disp_catalog}"

	eval "${_cmd}"
}

# ---------------------------------------------------------------------
# modify the display format

function f_listcat_output
{
	if [ "${disp_format}" = "CSV" ]; then
		cftCatalogFullToCsv "${opt_service}"

	elif [ "${disp_format}" = "RAW" ]; then
		cat -

	elif [ "${disp_format}" = "TABULAR" ]; then
		typeset _fcount="$(pathGetTempFile count)"
		cftCatalogFullToCsv "${opt_service}" | tee ${_fcount} | grep -avE '^\[cft.*displayed rows$' | csvToTabular
		grep -axE '^\[cft.*displayed rows$' ${_fcount}
	fi
}

# ---------------------------------------------------------------------

function verb_main {
	typeset -i _ret=0

	# check which node hosts the required service
	typeset _node="$(tabGetNode "${opt_service}")"
	if [ -z "${_node}" ]; then
		msgerr "'${opt_service}': no hosting node found (environment='${ttp_node_environment}')"
		let _ret+=1
	
	elif [ "${_node}" != "${TTP_NODE}" ]; then
		typeset _parms="$@"
		execRemote "${_node}" "${ttp_command} ${ttp_verb} ${_parms}" 
		return $?

	# we are on the right node
	else
		serviceSetenv "${opt_service}"

		if [ "${opt_general}" = "yes" -o "${opt_all}" = "yes" ]; then
			typeset _type
			for _type in auth cat com etb net parm prot xlate asy dna dsa lu62 sna tcp x25; do
				CFTUTIL CFTEXT type=${_type}
				let _ret+=$?
			done
		fi

		if [ "${opt_partner}" = "yes" -o "${opt_all}" = "yes" ]; then
			CFTUTIL CFTEXT type=part
			let _ret+=$?
		fi

		if [ "${opt_send}" = "yes" -o "${opt_all}" = "yes" ]; then
			CFTUTIL CFTEXT type=send
			let _ret+=$?
		fi

		if [ "${opt_receive}" = "yes" -o "${opt_all}" = "yes" ]; then
			CFTUTIL CFTEXT type=recv
			let _ret+=$?
		fi

		if [ "${opt_logs}" = "yes" -o "${opt_all}" = "yes" ]; then
			CFTUTIL CFTEXT type=log
			let _ret+=$?
		fi

		if [ "${opt_account}" = "yes" -o "${opt_all}" = "yes" ]; then
			CFTUTIL CFTEXT type=accnt
			let _ret+=$?
		fi

		# default for listing catalog is raw (unformatted) output
		# '--sql' option outputs as a SQL-like table
		# '--metrics' option outputs as a semi-comma ';' separated list
		if [ "${opt_catalog_set}" = "yes" ]; then
			f_listcat | f_listcat_output
			#f_listcat | formatOutput "${disp_format}" "${opt_headers}"
			#if [ "${opt_catalog}" = "full" ]; then
			#	if [ "${opt_format}" = "raw" ]; then
			#		f_listcat
			#	else
			#		f_listcat | cftCatalogFullTabular "${opt_service}"
			#	fi
			#else
			#	f_listcat
			#fi
			let _ret+=$?
		fi
	fi

	return ${_ret}
}
