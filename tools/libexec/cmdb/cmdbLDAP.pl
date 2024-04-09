#!/usr/bin/perl -w
# @(#) LDAP Inventory
#
# A script to provide the current inventory from LDAP to the TTP project.
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
#
# pwi 2015- 6-23 creation
# pwi 2015- 7-28 v2015.2 have a --check command-line option
# pwi 2015- 7-31 v2015.3 rewrite groups check + review comments
# pwi 2015- 8- 7 recursively include groups
# pwi 2015- 8- 7 add groups from pointing-to aliases
# pwi 2015- 8- 9 check pwiType=A vs. pwiAliasTo
# pwi 2015- 8-10 no more add groups from aliases (this is a buggy solution)
# pwi 2015- 8-11 mutualize host variables settings
# pwi 2015- 8-11 define alias_groups as list of groups of alias to the box
# pwi 2015- 8-13 always have a - maybe empty - aliasGroups
# pwi 2015- 8-13 add hostGroups list of groups of the host (aka Ansible group_names)
# pwi 2017- 6- 5 update to new LDAP schema
# pwi 2017- 6- 7 return as an array multiple values with same property name
# pwi 2017- 6- 9 action '--pvraw' outputs a raw list of physicals+virtuals 
# pwi 2017- 6-12 update to new LDAP schema
# pwi 2019- 5-12 restore pwiAnsibleVar attribute for a pwiHost class
# pwi 2019- 8- 1 no more output removed machines
# pwi 2021- 5-22 migrate from Ansible inventory to The Tools Project
#
use strict;
use File::Basename;
use Getopt::Long;
use JSON;
use Net::LDAP;
use Socket;

my $me = basename( $0 );
use constant { true => 1, false => 0 };
 
# auto-flush on socket
$| = 1;

my $errs = 0;
my $nbopts = $#ARGV;
my $opt_help_def = "no";
my $opt_help = false;
my $opt_version_def = "no";
my $opt_version = false;
my $opt_verbose_def = "no";
my $opt_verbose = false;

my $opt_host_def = "";
my $opt_host = $opt_host_def;
my $opt_root_def = "dc_example,dc=com";
my $opt_root = $opt_root_def;

my $opt_withremoved = false;

# ---------------------------------------------------------------------
sub msgErr( $ ){
	my $msg = shift;
	print STDERR "[$me] ".$msg;
}

# ---------------------------------------------------------------------
sub msg_help(){
	msg_version();
	print " Usage: $0 [options]
  --[no]help              print this message, and exit [${opt_help_def}]
  --[no]version           print script version, and exit [${opt_version_def}]
  --[no]verbose           run verbosely [$opt_verbose_def]
  --host=HOST             LDAP host [${opt_host_def}]
  --root=ROOT             LDAP root DN [${opt_root_def}]
";
}

# ---------------------------------------------------------------------
sub msg_version(){
	print ' CMDB LDAP dump v1.0-2021
 Copyright (©) 2021 Pierre Wieser <pwieser@trychlos.org>
';
}

# ---------------------------------------------------------------------
# dump a LDAP entry to stdout
sub dump_entry( $ ){
	my $entry = shift;
	my $removed = $entry->get_value( 'pwiRemoved' );
	if( !defined( $removed ) || $opt_withremoved ){
		print "dn: ".$entry->dn()."\n";
		my @classes = $entry->get_value( 'objectClass' );
		print "oc: ".join( ',', @classes )."\n";
		my @attributes = $entry->attributes();
		#print "at: ".join( ',', @attributes )."\n";
		foreach my $attr ( @attributes ){
			if( $attr ne 'objectClass' ){
				print "at: ".$attr.":".join( ',', $entry->get_value( $attr ))."\n";
			}
		}
	}
}

# ---------------------------------------------------------------------
# returns a hash of all domains and their properties (acts as a cache)
# indexed by the domain cn
sub read_all( $ ){
	my $ldap = shift;
	my $msg = $ldap->search(
			'base'  => "${opt_root}",
			'filter'=> "(objectClass=*)"
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

if( !GetOptions(
	"help!"			=> \$opt_help,
	"version!"		=> \$opt_version,
	"verbose!"		=> \$opt_verbose,
	"host:s"		=> \$opt_host,
	"root:s"		=> \$opt_root )){
		
		print "[$me] try '${0} --help' to get full usage syntax.\n";
		exit( 1 );
}

#print "nbopts=$nbopts\n";
$opt_help = 1 if $nbopts < 0;

if( $opt_help ){
	msg_help();
	exit( 0 );
}

if( $opt_version ){
	msg_version();
	exit( 0 );
}

if( $errs ){
	print "[$me] try '${0} --help' to get full usage syntax.\n";
	exit( $errs );
}

# open a LDAP connection
my $ldap = Net::LDAP->new( $opt_host );
if( !$ldap ){
	print STDERR "[$me] unable to open a LDAP connection to $opt_host";
	exit 1;
}
my $msg = $ldap->bind;
if( $msg->code ){
	print STDERR "[$me] ".$msg->error;
	exit 1;
}

# recursively dump the LDAP content
my @entries = read_all( $ldap );
foreach my $entry ( @entries ){
	dump_entry( $entry );
}

# cache domains and their properties
#$all_domains = read_all_domains( $ldap );
#print to_json( $all_domains, { utf8 => 1, pretty => 1 });

# cache sites and their properties
#$all_sites = read_all_sites( $ldap );
#print to_json( $all_sites, { utf8 => 1, pretty => 1 });

$ldap->unbind;
exit( $errs );
