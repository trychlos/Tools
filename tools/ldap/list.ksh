# @(#) list components of a LDAP directory
#
# @(@) This verb lists all the components of the specified LDAP directory.
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
# pwi 2021- 5-23 creation 

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help							display this online help and gracefully exit
verbose							verbose execution
host=<hostname>					LDAP host
root=<rootdn>					LDAP root DN
"
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
	opt_verbose_def="no"
	opt_host_def=""
	opt_root_def=""
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	#set -x
	typeset -i _ret=0

	# host is mandatory
	if [ -z "${opt_host}" ]; then
		msgErr "LDAP host is mandatory, has not been found"
		let _ret+=1
	fi

	# root is mandatory
	if [ -z "${opt_root}" ]; then
		msgErr "LDAP root DN is mandatory, has not been found"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# raw output is:
#
# A shell function to provide the content of a LDAP directory.
# It outputs the full LDAP content to stdout as a list of text lines.
#
# Example:
# 	dn: cn=guiraud.pwi,ou=domains,dc=trychlos,dc=pwi
#		description=The guiraud administrative domain. Used to manage the machines at Lormont.
# 	dn: cn=trychlos.pwi,ou=domains,dc=trychlos,dc=pwi
#		description=The trychlos.pwi administrative domain.
#		pwiProperty=sidAddonsDir=/opt/trychlos.pwi
#		pwiProperty=sidPerlDir=/opt/trychlos.pwi/Trychlos
# 	dn: cn=lor,ou=sites,dc=trychlos,dc=pwi
#		description=The site at Lormont
#		l=Lormont
# 	dn: cn=lat,ou=sites,dc=trychlos,dc=pwi
#		description=The site at Latresne.
#		l=Latresne
#		pwiProperty=sisAdminMail=itadmin@trychlos.pwi
#		pwiProperty=sisBackupServer=backup.trychlos.lan
#		pwiProperty=sisMailDomain=trychlos.pwi
#		pwiProperty=sisMeteringServer=monitor.trychlos.lan
#		pwiProperty=sisMonitorServer=monitor.trychlos.lan
#		pwiProperty=sisSiteDir=/home/ansible/trychlos.pwi
#		pwiProperty=sisTimeServer=ntp.trychlos.lan
# 	dn: cn=admin7,ou=hosts,dc=trychlos,dc=pwi
#		pwiSiteName=lat
#		pwiType=V
#		description=Administration box. CentOS 7.
#		pwiProperty=sihBasepckPackage=ack
#		pwiProperty=sihBasepckPackage=unzip
#		pwiProperty=sihBasepckPackage=zip
#		pwiProperty=sihHasLdapSrv

function f_ldap {
	typeset _host="${1}"
	typeset _root="${2}"
	typeset _me="${ttp_command} ${ttp_verb}"
	typeset -i _ret=0

	perl -se '{

		BEGIN {
			use Net::LDAP;
			use Socket;
		}

		# ---------------------------------------------------------------------
		# dump a LDAP entry to stdout

		sub dump_entry( $ ){
			my $entry = shift;
			print "dn: ".$entry->dn()."\n";
			my @classes = $entry->get_value( "objectClass" );
			print "oc: ".join( ",", @classes )."\n";
			my @attributes = $entry->attributes();
			#print "at: ".join( ",", @attributes )."\n";
			foreach my $attr ( @attributes ){
				if( $attr ne "objectClass" ){
					my @values = $entry->get_value( $attr );
					foreach my $value ( @values ){
						print "at: ".$attr.": ".$value."\n";
					}
				}
			}
		}

		# ---------------------------------------------------------------------
		# returns a hash of all domains and their properties (acts as a cache)
		# indexed by the domain cn

		sub read_all( $$ ){
			my $ldap = shift;
			my $root = shift;
			my $msg = $ldap->search(
					"base"   => ${root},
					"filter" => "(objectClass=*)"
			);
			$msg->code && die $msg->error;
			#foreach my $entry ( $msg->entries ){
			#	$entry->dump();
			#}
			return( $msg->entries );
		}

		# =====================================================================
		# MAIN
		# =====================================================================

		# open a LDAP connection
		my $ldap = Net::LDAP->new( $host );
		if( !$ldap ){
			print STDERR "[${_me}] unable to open a LDAP connection to ${_host}";
			exit 1;
		}
		my $msg = $ldap->bind;
		if( $msg->code ){
			print STDERR "[${_me}] ".$msg->error;
			exit 1;
		}
		# recursively dump the LDAP content
		my @entries = read_all( $ldap, $root );
		foreach my $entry ( @entries ){
			dump_entry( $entry );
		}
		$ldap->unbind;

	}' -- -me="${ttp_command} ${ttp_verb}" -host="${_host}" -root="${_root}"

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# LDAP access is provided by a dedicated Perl script
	f_ldap "${opt_host}" "${opt_root}"

	return ${_ret}
}
