#!/usr/bin/perl -w
# @(#) Ansible - Inventory
#
# A script to provide the current inventory from LDAP to Ansible.
#
# Set variables:
# - hostIp:      string "1.2.3.4" IPv4 address
# - aliasGroups: list of groups of aliases to the box
# - hostGroups:  list of groups of the name
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
#
# $Id: inventory.pl 5413 2019-08-02 22:08:52Z  $
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

my $opt_check_def = "no";
my $opt_check = false;
my $opt_byprops_def = "no";
my $opt_byprops = false;
my $opt_host_def = "";
my $opt_host = undef;
my $opt_list_def = "no";
my $opt_list = false;

my $opt_withhosts_def = "no";
my $opt_withhosts = false;
my $opt_grouped_def = "yes";
my $opt_grouped = true;
my $opt_meta_def = "yes";
my $opt_meta = true;
my $opt_raw_def = "no";
my $opt_raw = false;
my $opt_withremoved_def = "no";
my $opt_withremoved = false;

my $ldap_host = defined( $ENV{'ANSIBLE_LDAPHOST'} ) ? $ENV{'ANSIBLE_LDAPHOST'} : "";
my $ldap_root = defined( $ENV{'ANSIBLE_LDAPROOT'} ) ? $ENV{'ANSIBLE_LDAPROOT'} : "dc=ansible,dc=com";
my $ldap_site = defined( $ENV{'ANSIBLE_LDAPSITE'} ) ? $ENV{'ANSIBLE_LDAPSITE'} : "";
my $add_ip = true;
my $knownTypes = {
	'A' => "alias",
	'D' => "device",
	'P' => "physical",
	'V' => "virtual",
};
my $hostTypes = [ 'P','V' ];
my $all_domains = {};
my $all_sites = {};

# ---------------------------------------------------------------------
sub msgErr( $ ){
	my $msg = shift;
	print STDERR to_json(
		{ "[$me] ".$msg },
		{ utf8 => 1, pretty => 1 });
}

# ---------------------------------------------------------------------
sub msg_help(){
	msg_version();
	print " Usage: $0 [options]
  --[no]help              print this message, and exit [${opt_help_def}]
  --[no]version           print script version, and exit [${opt_version_def}]
  --[no]verbose           run verbosely [$opt_verbose_def]
  --[no]check             check inventory consistency [${opt_check_def}]
  --[no]byprops           returns hosts grouped by property [${opt_byprops_def}]
  --[no]withhosts         with --byprops, attach the hosts to each property [${opt_withhosts_def}]
  --host=[<hostname>]     [ansible] returns host variables [${opt_host_def}]
  --[no]list              [ansible] list hosts grouped per pwiType [${opt_list_def}]
  --[no]grouped           with --list, returns hosts grouped by pwiType [${opt_grouped_def}]
  --[no]meta              [ansible] with --list, returns variables for all hosts [${opt_meta_def}]
  --[no]raw               with --list, returns a raw list of physicals+virtuals [${opt_raw_def}]
  --[no]withremoved       display removed machines [${opt_withremoved_def}]
  
  --check, --byprops, --host and --list define the action of the script;
    these options are mutually exclusive.
  --withhosts qualifier should only be specified with the --byprops action.
  --wtihremoved qualifier may be specified with --byprops and --list actions.
  --grouped, --meta and --raw qualifiers should only be specified with the --list action.
  --raw option takes priority over --grouped and --meta ones, which are silently ignored.
  Surnumerous qualifiers are silently ignored. 
";
}

# ---------------------------------------------------------------------
sub msg_version(){
	print ' Ansible Inventory v5.2-2019
 Copyright (©) 2015,2016,2017,2018,2019 Pierre Wieser <pwieser@trychlos.org>
 $Id: inventory.pl 5413 2019-08-02 22:08:52Z  $
';
}

# ---------------------------------------------------------------------
# check that each inventory element defines a known 'pwiType' attribute
# pwiType is a must-have attribute of pwiHost class
# returns count of errs
sub check_pwitype( $$ ){
	my $ldap = shift;
	my $out = shift;
	my $errs = 0;
	# get all elements of the ou=devices,ou=lat
	my $msg = $ldap->search(
			'base'  => "ou=hosts,${ldap_root}",
			'filter'=> "(objectClass=pwiHost)",
			'attrs' => ['cn','dn','pwiType'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		$out->{totalElements} += 1;
		my $cn = $entry->get_value( 'cn' );
		my $dn = $entry->get_value( 'dn' );
		my $pwiType = $entry->get_value( 'pwiType' );
		if( !defined( $pwiType )){
			push( @{$out->{msgErrs}}, "[$me] $dn: undefined 'pwiType' attribute" );
			$errs += 1;
		} elsif( !defined( $knownTypes->{$pwiType} )){
			push( @{$out->{msgErrs}}, "[$me] $dn: pwiType=$pwiType: unmanaged value" );
			$errs += 1;
		} else {
			#push( @{$out->{pwiType}{$pwiType}{list}}, $cn );
			$out->{pwiType}{$pwiType}{count} += 1;
		}
	}
	push( @{$out->{checks}}, "[$me] check that each inventory element defines a known 'pwiType' attribute: ".( $errs ? "errors=$errs":"OK" ));
	return( $errs );
}

# ---------------------------------------------------------------------
# check that alias have one and only one pwiAliasTo attribute
# note that pwiAliasTo attribute is defined as 'single-value' in ldap
# check that this entry does not hold any pwiProperty (this is only a
#  DNS alias)
# return count of errors
sub check_typea( $$ ){
	my $ldap = shift;
	my $out = shift;
	# get all elements of the Names ou
	my $msg = $ldap->search(
			'base'  => "ou=hosts,${ldap_root}",
			'filter'=> "(&(objectClass=pwiHost)(pwiType=A))",
			'attrs' => ['dn','pwiAliasTo','pwiProperty'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		my $dn = $entry->get_value( 'dn' );
		my @aliases = $entry->get_value( 'pwiAliasTo' );
		if( @aliases == 0 ){
			push( @{$out->{msgErrs}}, "[$me] $dn: pwiAliasTo attribute not found, but should" );
			$errs += 1;
		} elsif( @aliases > 1 ){
			push( @{$out->{msgErrs}}, "[$me] $dn: more that one pwiAliasto attribute is defined: ".join( ",", @aliases ));
			$errs += 1;
		}
		my @properties = $entry->get_value( 'pwiProperty' );
		if( @properties > 0 ){
			push( @{$out->{msgErrs}}, "[$me] $dn: pwiProperty attribute found while this entry is expected to only define a DNS alias" );
			$errs += 1;
		}
	}
	push( @{$out->{checks}}, "[$me] check that pwiType=A is associated with only one pwiAliasTo attribute: ".( $errs ? "errors=$errs":"OK" ));
	return( $errs );
}

# ---------------------------------------------------------------------
# check that AliasTo is only defined for pwiType=A
# return count of errors
sub check_aliasto( $$ ){
	my $ldap = shift;
	my $out = shift;
	# get all elements of the Names ou
	my $msg = $ldap->search(
			'base'  => "ou=hosts,${ldap_root}",
			'filter'=> "(objectClass=pwiHost)",
			'attrs' => ['dn','pwiType','pwiAliasTo'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		my $dn = $entry->get_value( 'dn' );
		my $pwitype = $entry->get_value( 'pwiType' );
		my @aliases = $entry->get_value( 'pwiAliasTo' );
		# ignore non-defined AliasTo and bad counts (checked below)
		if( @aliases == 1 && $pwitype ne "A" ){
			push( @{$out->{msgErrs}}, "[$me] $dn: pwiAliasTo attribute is defined for pwiType=$pwitype, but shouldn't" );
			$errs += 1;
		}
	}
	push( @{$out->{checks}}, "[$me] check that pwiAliasTo is only defined for pwiType=A: ".( $errs ? "errors=$errs":"OK" ));
	return( $errs );
}

# ---------------------------------------------------------------------
# check that deprecated attribute is not used
# return count of entries which use this attribute
sub check_deprecated_attr( $$$ ){
	my $ldap = shift;
	my $out = shift;
	my $attr = shift;
	# get all elements of the ou=devices,ou=lat which holds this attribute
	my $msg = $ldap->search(
			'base'  => "ou=hosts,${ldap_root}",
			'filter'=> "($attr=*)",
			'attrs' => ['dn'] );
	$msg->code && die $msg->error;
	my $count = 0+$msg->entries;
	push( @{$out->{checks}}, "[$me] check for entries which use deprecated '".$attr."' attribute: ".$count );
	return( $count );
}

# ---------------------------------------------------------------------
# check that deprecated class is not used
# return count of entries which use this class
sub check_deprecated_class( $$$ ){
	my $ldap = shift;
	my $out = shift;
	my $class = shift;
	# get all elements of the ou=devices,ou=lat which holds this attribute
	my $msg = $ldap->search(
			'base'  => "ou=hosts,${ldap_root}",
			'filter'=> "($class=*)",
			'attrs' => ['dn'] );
	$msg->code && die $msg->error;
	my $count = 0+$msg->entries;
	push( @{$out->{checks}}, "[$me] check for entries which use deprecated '".$class."' class: ".$count );
	return( $count );
}

# ---------------------------------------------------------------------
# concatenate hash b to hash a, both passed by reference
sub concatenate_hash( $$ ){
	my $outref = shift;
	my $addref = shift;
	foreach my $key( keys %$addref ){
		$outref->{$key} = $addref->{$key}
	}
}

# ---------------------------------------------------------------------
# returns an array with known dynamic domain variables
sub dyn_domain_list(){
	my $out = [
	];
	return( $out );
}

# ---------------------------------------------------------------------
# returns an array with known dynamic host variables
sub dyn_host_list(){
	my $out = [
		'dihSiteDn'
	];
	return( $out );
}

# ---------------------------------------------------------------------
# add to passed-in hash the computed dynamic host variables
#  and return it
sub dyn_host_vars( $$ ){
	my $site = shift;
	my $vars = shift;
	$site = $ldap_site if !defined( $site );
	$vars->{dihSiteDn} = "cn=${site},ou=sites,${ldap_root}";
	return( $vars );
}

# ---------------------------------------------------------------------
# returns an array with known dynamic site variables
sub dyn_site_list(){
	my $out = [
		'disAddonsDir',
		'disAdminMail',
		'disBackupServer',
		'disDomainCn',
		'disDomainDn',
		'disMailDomain',
		'disMeteringServer',
		'disMonitorServer',
		'disPerlDir',
		'disTimeServer'
	];
	return( $out );
}

# ---------------------------------------------------------------------
# add to passed-in hash the computed dynamic site variables
#  and return it
sub dyn_site_vars( $$ ){
	my $domain_cn = shift;
	my $vars = shift;
	$vars->{disDomainCn} = ${domain_cn};
	$vars->{disDomainDn} = "cn=${domain_cn},ou=domains,${ldap_root}";
	#print "domain_cn=".$domain_cn.", disDomainDn=".$vars->{disDomainDn}."\n";
	my ( $n, $v );
	$n = "AddonsDir"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "AdminMail";$v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "BackupServer"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "MailDomain"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "MeteringServer"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "MonitorServer"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "PerlDir"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	$n = "TimeServer"; $v = merge_sd( $vars, $n ); $vars->{"dis".$n} = $v if defined $v;
	#foreach my $k ( keys %$vars ){
	#	print "$k=".$vars->{$k}."\n";
	#}
	return( $vars );
}

# ---------------------------------------------------------------------
# returns a hash of properties for the specified host
# + dynamic properties dihSiteDn and dihDomain
sub get_host_props( $$ ){
	my $ldap = shift;
	my $host = shift;
	my $msg = $ldap->search(
		'base'  => "ou=hosts,${ldap_root}",
		'filter'=> "(&(objectClass=pwiHost)(cn=$host))",
		'attrs' => ['pwiAnsibleVar','pwiProperty','pwiRemoved','pwiSiteName'] );
	$msg->code && die $msg->error;
	my $out = {};
	foreach my $entry ( $msg->entries ){
		#$entry->dump();
		my $removed = $entry->get_value( 'pwiRemoved' );
		next if defined( $removed );
		# get static properties
		my @vars = $entry->get_value( 'pwiProperty' );
		concatenate_hash( $out, parse_props( \@vars ));
		#$out += parse_props( \@vars );
		# add Ansible variables for this host
		@vars = $entry->get_value( 'pwiAnsibleVar' );
		concatenate_hash( $out, parse_props( \@vars ));
		#$out += parse_props( \@vars );
		# add dynamic variables
		my $site = $entry->get_value( 'pwiSiteName' );
		if( !defined( $site )){
			msgErr( "pwiHost=$host doesn't have pwiSiteName attribute" );
		} else {
			dyn_host_vars( $site, $out );
		}
	}
	return( $out );
}

# ---------------------------------------------------------------------
# Returns an alpha-ordered array of known hosts for this type
sub get_hosts_by_type( $$ ){
	my $ldap = shift;
	my $type = shift;
	my $hosts = [];
	my $msg = $ldap->search(
		'base'  => "ou=hosts,${ldap_root}",
		'filter'=> "(&(objectClass=pwiHost)(pwiType=$type))",
		'attrs' => ['cn','pwiRemoved'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		my $cn = $entry->get_value( 'cn' );
		my $removed = $entry->get_value( 'pwiRemoved' );
		push( @$hosts, $cn ) if !defined( $removed ) or $opt_withremoved;
	}
	return( sort { $a cmp $b } @$hosts );
}

# ---------------------------------------------------------------------
# Returns an alpha-ordered array of known hosts
sub get_hosts_list( $ ){
	my $ldap = shift;
	my $hosts = [];
	my $msg = $ldap->search(
		'base'  => "ou=hosts,${ldap_root}",
		'filter'=> "(&(objectClass=pwiHost)(pwiSiteName=$ldap_site))",
		'attrs' => ['cn','pwiRemoved'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		my $cn = $entry->get_value( 'cn' );
		my $removed = $entry->get_value( 'pwiRemoved' );
		push( @$hosts, $cn ) if !defined( $removed ) or $opt_withremoved;
	}
	return( sort { $a cmp $b } @$hosts );
}

# ---------------------------------------------------------------------
# Returns an alpha-ordered array of hosts which hold this property
sub get_prop_hosts( $$ ){
	my $ldap = shift;
	my $prop = shift;
	my $hosts = [];
	my $msg = $ldap->search(
		'base'  => "ou=hosts,${ldap_root}",
		'filter'=> "(|(pwiProperty=$prop)(pwiProperty=$prop=*))",
		'attrs' => ['cn','pwiRemoved'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		my $cn = $entry->get_value( 'cn' );
		my $removed = $entry->get_value( 'pwiRemoved' );
		push( @$hosts, $cn ) if !defined( $removed ) or $opt_withremoved;
	}
	return( sort { $a cmp $b } @$hosts );
}

# ---------------------------------------------------------------------
# Returns an alpha-ordered array of distinct knwon static properties
#  for both pwiDomain, pwiSite and pwiHost classes
sub get_props_list( $ ){
	my $ldap = shift;
	my $props = [];
	my $msg = $ldap->search(
		'base'  => "${ldap_root}",
		'filter'=> "(|(objectClass=pwiDomain)(objectClass=pwiSite)(objectClass=pwiHost)(objectClass=pwiLan))",
		'attrs' => ['pwiProperty'] );
	$msg->code && die $msg->error;
	foreach my $entry ( $msg->entries ){
		my @vars = $entry->get_value( 'pwiProperty' );
		if( @vars ){
			foreach my $var ( @vars ){
				my ( $name, $value ) = split( '\s*=\s*', $var );
				push( @$props, $name );
			}
		}
	}
	return( sort { $a cmp $b } uniq( @$props ));
}

# ---------------------------------------------------------------------
# returns the host variable value if set, else the site value if set,
#  else the domain value if set, or undef.
sub merge_hsd( $$ ){
	my $vars = shift;
	my $varname = shift;
	my $out = undef;
	if( defined( $vars->{'sih'.$varname} )){
		$out = $vars->{'sih'.$varname};
	} elsif( defined( $vars->{dihSiteDn} )){
		my $site_cn = parse_cn( $vars->{dihSiteDn} );
		$out = merge_sd( $all_sites->{$site_cn}, $varname );
	} else {
		msgErr( "dihSiteDn not defined" );
	}
	return( $out );
}

# ---------------------------------------------------------------------
# returns the site variable value if set, else the domain value if set,
#  or undef.
sub merge_sd( $$ ){
	my $vars = shift;
	my $varname = shift;
	my $out = undef;
	if( defined( $vars->{'sis'.$varname} )){
		$out = $vars->{'sis'.$varname};
	} elsif( defined( $vars->{disDomainDn} )){
		my $domain_cn = parse_cn( $vars->{disDomainDn} );
		if( defined( ${all_domains}->{$domain_cn}{'sid'.$varname} )){
			$out = ${all_domains}->{$domain_cn}{'sid'.$varname};
		}
	} else {
		msgErr( "disDomainDn not defined" );
	}
	return( $out );
}

# ---------------------------------------------------------------------
# extract the cn from the dn
sub parse_cn( $ ){
	my $dn = shift;
	$dn =~ s/,.*$//;
	my ( $foo, $cn ) = split( '\s*=\s*', $dn );
	return( $cn );
}

# ---------------------------------------------------------------------
# convert a list of 'a=b' strings to a hash of a => b key/values
# returns a hash of properties
sub parse_props( $ ){
	my $vars = shift;
	my $out = {};
	if( @$vars ){
		foreach my $var ( @$vars ){
			my ( $name, $value ) = split( '\s*=\s*', $var );
			# interpretation of an empty value is left to the application
			$value = '' if !defined( $value );
			if( defined( $out->{$name} )){
				if( ref( $out->{$name} ) eq 'ARRAY' ){
					push( @{$out->{$name}}, $value );
				} else {
					my $tmp = [ $out->{$name}, $value ];
					$out->{$name} = $tmp;
				}
			} else {
				$out->{$name} = $value;
			}
		}
	}
	return( $out );
}

# ---------------------------------------------------------------------
# returns a hash of all domains and their properties (acts as a cache)
# indexed by the domain cn
sub read_all_domains( $ ){
	my $ldap = shift;
	my $msg = $ldap->search(
			'base'  => "ou=domains,${ldap_root}",
			'filter'=> "(objectClass=pwiDomain)",
			'attrs' => ['cn','pwiProperty','pwiRemoved'] );
	$msg->code && die $msg->error;
	my $out = {};
	foreach my $entry ( $msg->entries ){
		#$entry->dump();
		my $cn = $entry->get_value( 'cn' );
		next if !defined( $cn );
		my $removed = $entry->get_value( 'pwiRemoved' );
		next if defined( $removed );
		my @vars = $entry->get_value( 'pwiProperty' );
		$out->{$cn} = parse_props( \@vars );
	}
	return( $out );
}

# ---------------------------------------------------------------------
# returns a hash of all sites and their properties (acts as a cache)
# indexed by the site cn
sub read_all_sites( $ ){
	my $ldap = shift;
	my $msg = $ldap->search(
			'base'  => "ou=sites,${ldap_root}",
			'filter'=> "(objectClass=pwiSite)",
			'attrs' => ['cn','pwiProperty','pwiRemoved','pwiDomainName'] );
	$msg->code && die $msg->error;
	my $out = {};
	foreach my $entry ( $msg->entries ){
		#$entry->dump();
		my $cn = $entry->get_value( 'cn' );
		next if !defined( $cn );
		my $removed = $entry->get_value( 'pwiRemoved' );
		next if defined( $removed );
		# add static properties
		my @props = $entry->get_value( 'pwiProperty' );
		my $vars = parse_props( \@props );
		# add dynamic variables
		my $domain_cn = $entry->get_value( 'pwiDomainName' );
		if( !defined( $domain_cn )){
			msgErr( "pwiSite=$cn doesn't have pwiDomainName attribute" );
		} elsif( !defined( ${all_domains}->{$domain_cn} )){
			msgErr( "pwiDomain=$domain_cn is not defined" );
		} else {
			dyn_site_vars( $domain_cn, $vars );
		}
		$out->{$cn} = $vars;
	}
	return( $out );
}

# ---------------------------------------------------------------------
# Returns an empty string or the IPv4 address
sub read_ip( $ ){
	my $host = shift;
	my $ip = "";
	my $ipn = inet_aton( $host );
	$ip = inet_ntoa( $ipn ) if defined $ipn;
	#print "host=$host, ip=$ip\n";
	return( $ip );
}

# ---------------------------------------------------------------------
# https://perlmaven.com/unique-values-in-an-array-in-perl
sub uniq { my %seen; return grep { !$seen{$_}++ } @_; }

# ---------------------------------------------------------------------
# check inventory consistency
#  - that elements in ou=hosts,dc=trychlos,dc=pwi:
#    . have a pwiType attribute with an accepted value
#    . are attached to a pwiSite entry via the pwiSiteName attribute.
#  - that elements in ou=sites,dc=trychlos,dc=pwi:
#    . are attached to a pwiDomain entry via the pwiDomainName attribute.
# output JSON formatted data:
#    - checks/
#      - <msg>/
#        - errors: <count>
#    - pwiType/<type>:
#      - name:  the group name defined by this type
#      - count: the count of elements of this type
##      - list:  the list of devices of this type
##        no more return the list as of v5.0.2017
#    - totalElements: total count of devices
#    - totalOK:       total count of ok devices
#    - totalErrs:     total count of errors
sub action_check( $ ){
	my $ldap = shift;
	# initialize the output hash
	my $output = {};
	$output->{msgErrs} = [];
	$output->{totalElements} = 0;
	$output->{totalErrs} = 0;
	foreach my $key( keys %{$knownTypes} ){
		#$output->{pwiType}{$key}{list} = [];
		$output->{pwiType}{$key}{name} = $knownTypes->{$key};
		$output->{pwiType}{$key}{count} = 0;
	}
	$output->{checks} = [];
	# check that each inventory element defines a known 'pwiType'
	$output->{totalErrs} += check_pwitype( $ldap, $output );
	# check that each pwiType=A have one and only one AliasTo, and no Property
	$output->{totalErrs} += check_typea( $ldap, $output );
	# check that pwiAliasTo is only used by pwiType=A
	$output->{totalErrs} += check_aliasto( $ldap, $output );
	# check that deprecated attributes are no more used
	$output->{totalErrs} += check_deprecated_attr( $ldap, $output, 'pwiAnsibleMemberOf' );
	$output->{totalErrs} += check_deprecated_attr( $ldap, $output, 'pwiAnsibleInclude' );
	# check that deprecated classes are no more used
	$output->{totalErrs} += check_deprecated_class( $ldap, $output, 'pwiAnsibleGroup' );
	$output->{totalErrs} += check_deprecated_class( $ldap, $output, 'pwiDevice' );
	print to_json( $output, { utf8 => 1, pretty => 1 });
}

# ---------------------------------------------------------------------
# returns a hash of properties, each pointing to an alpha-ordered array of hosts
sub action_byprops( $ ){
	my $ldap = shift;
	my $out = {};
	my $props = [];
	@$props = get_props_list( $ldap );
	my $hosts = [];
	@$hosts = get_hosts_list( $ldap );
	my $dyns = [];
	$dyns = dyn_host_list(); push( @$props, @$dyns );
	$dyns = dyn_site_list(); push( @$props, @$dyns );
	$dyns = dyn_domain_list(); push( @$props, @$dyns );
	if( $opt_withhosts ){
		foreach my $prop ( @$props ){
			$out->{properties}->{$prop} = [];
			if( $prop =~ /^s/ ){
				my $hosts_prop = [];
				@$hosts_prop = get_prop_hosts( $ldap, $prop );
				push( @{$out->{properties}->{$prop}}, @$hosts_prop );
			} elsif( $prop =~ /^d/ ){
				foreach my $host ( @$hosts ){
					my $hprops = get_host_props( $ldap, $host );
					push( @{$out->{properties}->{$prop}}, $host ) if defined $hprops->{$prop};
				}
			}
		}
	} else {
		$out->{properties} = $props;
	}
	print to_json( $out, { utf8 => 1, pretty => 1 });
}

# ---------------------------------------------------------------------
# list variables for the specified host
sub action_host( $ ){
	my $ldap = shift;
	my $out = get_host_props( $ldap, $opt_host );
	print to_json( $out, { utf8 => 1, pretty => 1 });
}

# ---------------------------------------------------------------------
# From: http://docs.ansible.com/ansible/dev_guide/developing_inventory.html
# List groups and hosts from LDAP inventory.
# We provide here the list of hosts:
# - either grouped by pwiType (default)
# - or as a single 'all->hosts' list if '--nogrouped' option if specified
# We provide also an array '_meta->hostvars' unless the '--nometa' option
# is specified.
# Last, the site-wide properties are appended as a 'all->vars' hash.
sub action_list( $ ){
	my $ldap = shift;
	my $out = {};
	my $hosts = [];
	@$hosts = get_hosts_list( $ldap );
	# --raw qualifier takes priority over --grouped and --meta
	if( $opt_raw ){
		my $hosts = [];
		push( @$hosts, get_hosts_by_type( $ldap, 'P' ));
		push( @$hosts, get_hosts_by_type( $ldap, 'V' ));
		foreach( @$hosts ){
			print $_."\n";
		}
	} else {
		# --[no]grouped option is only honored with the --list action
		if( $opt_grouped ){
			foreach my $type ( @$hostTypes ){
				@{$out->{$knownTypes->{$type}}} = get_hosts_by_type( $ldap, $type );
			}
		} else {
			@{$out->{all}{hosts}} = $hosts;
		}
		# --[no]meta option is only honored with the --list action
		if( $opt_meta ){
			$out->{_meta}{hostvars} = {};
			foreach my $host ( @$hosts ){
				my $props = get_host_props( $ldap, $host );
				# does not return empty hash
				if( %$props ){
					$out->{_meta}{hostvars}{$host} = $props;
				}
			}
		}
		$out->{all}{vars} = ${all_sites}->{$ldap_site};
		print to_json( $out, { utf8 => 1, pretty => 1 });
	}
}

# =====================================================================
# MAIN
# =====================================================================

if( !GetOptions(
	"help!"			=> \$opt_help,
	"version!"		=> \$opt_version,
	"verbose!"		=> \$opt_verbose,
	"check!"		=> \$opt_check,
	"byprops!"		=> \$opt_byprops,
	"host:s"		=> \$opt_host,
	"list!"			=> \$opt_list,
	"grouped!"		=> \$opt_grouped,
	"meta!"			=> \$opt_meta,
	"raw!"			=> \$opt_raw,
	"withhosts!"	=> \$opt_withhosts,
	"withremoved!"	=> \$opt_withremoved )){
		
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

# --check, --list and --host are incompatible
# --meta may only be specified with --list
my $c = 0;
$c += 1 if $opt_check;
$c += 1 if $opt_byprops;
$c += 1 if defined $opt_host;
$c += 1 if $opt_list;

if( $c == 0 ){
	print "[$me] at least one of '--check', '--byprops', '--host=<host>' and '--list' options must be specified\n";
	$errs += 1;

} elsif( $c > 1 ){
	print "[$me] only one of '--check', '--byprops', '--host=<host>' and '--list' options must be specified\n";
	$errs += 1;
}

if( defined( $opt_host ) && !length( $opt_host )){
	print  "[$me] --host must be qualified with a hostname\n";
	$errs += 1;
}

if( $errs ){
	print "[$me] try '${0} --help' to get full usage syntax.\n";
	exit( $errs );
}

# open a LDAP connection
my $ldap = Net::LDAP->new( $ldap_host );
if( !$ldap ){
	print to_json(
		{ "[$me] unable to open a LDAP connection to $ldap_host" },
		{ utf8 => 1, pretty => 1 });
	exit 1;
}
my $msg = $ldap->bind;
if( $msg->code ){
	print to_json(
		{ "[$me] ".$msg->error },
		{ utf8 => 1, pretty => 1 });
	exit 1;
}

# cache domains and their properties
$all_domains = read_all_domains( $ldap );
#print to_json( $all_domains, { utf8 => 1, pretty => 1 });

# cache sites and their properties
$all_sites = read_all_sites( $ldap );
#print to_json( $all_sites, { utf8 => 1, pretty => 1 });

# check the consistency of the inventory
if( $opt_check ){
	action_check( $ldap );

# list the used distinct properties in alpha order
} elsif( $opt_byprops ){
	action_byprops( $ldap );

# Ansible standard option to get the variables associated with a host
} elsif( $opt_host ){
	action_host( $ldap );

# Ansible standard option to get the host inventory by group
# Returns here the list of hosts in ascending alpha order
} elsif( $opt_list ){
	action_list( $ldap );
}

$ldap->unbind;
exit( $errs );
