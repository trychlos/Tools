# @(#) filter stdin stream to stdout
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
#   use case: cft.sh list output a tabular format in 95 columns
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
columns=<col1,col2,...|ALL>		a comma-separated list of columns number to be outputed (counted from 1)
insep=<sep>                   	the input field-separator regular expression
outsep=<sep>					the output field-separator string
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
	opt_columns_def="ALL"
	opt_insep_def="\\s+"
	opt_insep_def_disp="\\\s+"
	opt_outsep_def=" | "
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# columns must be specified
	if [ -z "${opt_columns}" ]; then
		msgErr "output columns list is mandatory"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	perl -se '{
		@columns = split( /,/, $columns );
		while( <STDIN> ){
			chomp;
			@line = split /${insep}/;
			$numcol = 0;
			if( $columns eq "ALL" ){
				foreach $field ( @field ){
					print $outsep if $numcol;
					print $field;
					$numcol += 1;
				}
			} else {
				foreach $col ( @columns ){
					print $outsep if $numcol;
					print $line[$col];
					$numcol += 1;
				}
			}
			print "\n";
		}
	}' -- -columns="${opt_columns}" -outsep="${opt_outsep}" -insep="${opt_insep}"

	return ${_ret}
}
