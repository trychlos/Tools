# @(#) reorder, filter and reformat columns from stdin stream to stdout
#
# @(#) Accepts any columns-like (aka CSV) input format.
# @(#) If headers are not defined as the first input row, then columns are numbered (from 1)
# @(#) instead of being named. The '--outnames' option may be added to add a name to each
# @(#) outputed column.
# @(#) Default is to reproduce to output the same columns-like format as the output,
# @(#) with the same columns population, i.e. to do nothing. 
# @(#) Output field separator is ignored when outputting in JSON/TABULAR formats.
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
#   use case: 'cft.sh list' output a tabular format in 95 columns
#             and has to go into a specific table structure
#
#   cft.sh list -service "${cft_service}" -catalog=full -mode=tabular | \
#	  grep -ve '^\[cft\.sh' | \
#	  ttp.sh filter -columns 3,4,2,6 | \
#	  tail -n +3 > ${ftmp}
#
# pwi 2013- 6-23 creation
# pwi 2013- 7-18 review options dynamic computing
# pwi 2017- 6-21 publish the release at last
# pwi 2021-12-27 extend the verb to tabular and json formats

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help			 				display this online help and gracefully exit
verbose							execute verbosely
inheaders						columns names are defined on first input row
insep=<sep>                   	the input field-separator regular expression
outcols=<num1,num2,...|ALL>		a comma-separated list of columns number to be outputed (counted from 1)
outfmt={CSV|JSON|TABULAR}		(case insensitive) output format
outheaders						whether to reproduce the headers on output
outnames=<name1,name2,...>		a comma-separated list of outputed columns names
outsep=<sep>					the output CSV-only field-separator string
screenwidth						keep tabular output in screen width
prefixed						whether outputed lines should be standard-prefixed
counter							whether to add a data rows counter at the end
maxcount=<n>					only display n data rows
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
# note that consistency sake, defaults here should be the same than those
# of filterOutput() function

function verb_arg_set_defaults {
	opt_verbose_def="no"
	opt_inheaders_def="yes"
	opt_insep_def=";"
	#opt_insep_def_disp="\\\s+"
	opt_outcols_def="ALL"
	opt_outfmt_def="CSV"
	opt_outheaders_def="yes"
	opt_outnames_def=""
	opt_outsep_def=";"
	opt_screenwidth_def="yes"
	opt_prefixed_def="no"
	opt_counter_def="no"
	opt_maxcount_def=-1
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# arguments are mandatory and must be set
	if [ -z "${opt_insep}" ]; then
		msgErr "input field-separator is mandatory"
		let _ret+=1
	fi
	if [ -z "${opt_outcols}" ]; then
		msgErr "output columns list is mandatory"
		let _ret+=1
	fi
	if [ -z "${opt_outsep}" ]; then
		msgErr "output field-separator is mandatory"
		let _ret+=1
	fi

	# check output format
	opt_outfmt="$(filterCheckFormat outfmt "${opt_outfmt}")"
	let _ret+=$?

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	filterOutput \
		"${opt_verbose}" \
		"${opt_inheaders}" "${opt_insep}" \
		"${opt_outcols}" "${opt_outfmt}" "${opt_outheaders}" "${opt_outnames}" "${opt_outsep}" \
		"${opt_screenwidth}" "${opt_prefixed}" "${opt_counter}" "${opt_maxcount}"

	return ${_ret}
}
