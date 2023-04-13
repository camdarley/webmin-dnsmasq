#!/usr/bin/perl
#
#    DNSMasq Webmin Module - dns_edit.cgi;  upstream server edit
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
#    This module inherited from the DNSMasq Webmin module by Neil Fisher

do '../web-lib.pl';
do '../ui-lib.pl';
do 'dnsmasq-lib.pl';

$|=1;
&init_config("DNSMasq");

%access=&get_module_acl;

## put in ACL checks here if needed


## sanity checks


## Insert Output code here
# read config file
$config_file = &read_file_lines( $config{config_file} );
# pass into data structure
&parse_config_file( \%config, \$config_file );
# read posted data
&ReadParse();
# check for errors in read config
if( $config{errors} > 0 ) {
	&header( "DNSMasq settings", "" );
	print "<hr><h2>";
	print $text{warn_errors};
	print $config{errors};
	print $text{didnt_apply};
	print "</h3><hr>\n";
	&footer( "/", $text{'index'});
	exit;
}
# adjust everything to what we got
#
&header( "DNSMasq settings", "" );
print "<h2>".$text{srv_edit}."</h2>";
print &ui_form_start( "srv_edit_apply.cgi", "post" );
print &ui_hidden( "idx", $in{idx} );
print "<br>".$text{in_use}.&ui_yesno_radio( "used",
				($config{servers}[$in{idx}]{used})?1:0 );
print "<br>".$text{srv_named}.&ui_yesno_radio( "named", 
				($config{servers}[$in{idx}]{domain_used})?1:0 );
print "<br>".$text{srv_name};
print &ui_textbox( "name", $config{servers}[$in{idx}]{domain}, 50 );
print "<br>".$text{srv_addr};
print &ui_textbox( "addr", $config{servers}[$in{idx}]{address}, 18 );
print "<br><br>" . &ui_submit( $text{'save_button'} )."<br>";
print &ui_form_end();
print "<a href=delete.cgi?idx=".$in{idx}."&what=servers&where=servers.cgi".
	">".$text{delet}."</a>";
#print "<a href=dns_del.cgi?idx=".$in{idx}.">".$text{delet}."</a>";
print "<br><a href=servers.cgi>".$text{servers_config}."</a>";
&footer( "/", $text{'index'});
#

# 
# sub-routines
#
### END of dns_edit.cgi ###.
