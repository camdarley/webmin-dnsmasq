#!/usr/bin/perl
#
#    DNSMasq Webmin Module - index.cgi; Main navigation
#    Copyright (C) 2023 by Loren Cress
#    
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    This module based on the DNSMasq Webmin module originally written by Neil Fisher

require 'dnsmasq-lib.pl';

require 'dns.cgi';
require 'dhcp.cgi';
require 'tftp.cgi';

# $|=1;

my %access=&get_module_acl();

## put in ACL checks here if needed

## sanity checks

# uses the index_title entry from ./lang/en or appropriate

## Insert Output code here
# read config file
my $config_filename = $config{config_file};
my $config_file = &read_file_lines( $config_filename );

&parse_config_file( \%dnsmconfig, \$config_file, $config_filename );

# read posted data
&ReadParse();

my ($error_check_action, $error_check_result) = &check_for_file_errors( $0, $text{"index_dns_settings"}, \%dnsmconfig );
if ($error_check_action eq "redirect") {
    &redirect ( $error_check_result );
}

&ui_print_header(undef, $text{"index_title"}, "", "intro", 1, 0, 0, &restart_button());
print &header_style();
print $error_check_result;

my $tab = "dns";
if ( defined ($in{"tab"}) ) {
    $tab = $in{"tab"};
}

my @tabs = (   [ 'dns', $text{'index_dns_settings'} ],
            [ 'dhcp', $text{'index_dhcp_settings'} ],
            [ 'tftp', $text{'index_tftp_settings'} ] );
print ui_tabs_start(\@tabs, 'tab', $tab);

print ui_tabs_start_tab('tab', 'dns');
show_dns_settings();
print ui_tabs_end_tab('tab', 'dns');

print ui_tabs_start_tab('tab', 'dhcp');
show_dhcp_settings();
print ui_tabs_end_tab('tab', 'dhcp');

print ui_tabs_start_tab('tab', 'tftp');
show_tftp_settings();
print ui_tabs_end_tab('tab', 'tftp');

print ui_tabs_end();

# uses the index entry in /lang/en

## if subroutines are not in an extra file put them here

### END of index.cgi ###.
