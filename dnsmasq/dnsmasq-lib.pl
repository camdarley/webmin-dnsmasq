#
# dnsmasq-lib.pl
#
# dnsmasq webmin module library module
#

BEGIN { push(@INC, ".."); };
use POSIX 'ceil';
use URI::Escape;
use WebminCore;
init_config();
our %access = &get_module_acl();
require 'parse-config-lib.pl';

our @radiodefaultno = ( 0, $text{"default"} );
our @radioyes = ( 1, "Yes" );
our @defaultoryes = ( \@radiodefaultno, \@radioyes );
# our @radiodefaultyes = ( 1, "Default" );
# our @radiono = ( 0, "No" );
# our @defaultorno = ( \@radiodefaultyes, \@radiono );
our @radioval = ( 1, " " );
our @defaultorval = ( \@radiodefaultno, \@radioval );
our $td_left = "style=\"text-align: left; width: auto;\"";
our $td_label = "style=\"text-align: left; width: auto; word-break: break-word; overflow-wrap: break-word;\"";
our $td_right = "style=\"text-align: right; width: auto;\"";

sub radio_default_or_yes {
    my ($def) = @_;
    my $default_text = ( $def == 0 ? "No" : "(no)" );
    my $default_mouseover = &ui_help($default_text);
    # my @radio_default_no = ( 0, "Default" . ( $def ? " ($def)" : "" ) );
    my @radio_default_no = ( 0, "Default" . $default_mouseover );
    return ( \@radio_default_no, \@radioyes );
}

sub radio_default_or_val {
    my ($def) = @_;
    my $default_text = ( $def ? $def : "(none)" );
    my $default_mouseover = &ui_help($default_text);
    # my @radio_default_no = ( 0, "Default" . ( $d ? " ($d)" : "" ) );
    my @radio_default_no = ( 0, "Default" . $default_mouseover );
    return ( \@radio_default_no, \@radioval );
}

# Returns HTML for a link to put in the top-right corner of every page
sub restart_button {
    return undef if ($config{'restart_pos'} == 2);
    my $args = "returnto=".&urlize(&this_url());
    if (&is_dnsmasq_running()) {
        return ($access{'restart'} ?
            "<a href='restart.cgi?" . $args . "'>" . $text{"index_button_restart"} . "</a><br>\n" : "").
            ($access{'start'} ?
            "<a href='stop.cgi?" . $args . "'>" . $text{"index_button_stop"} . "</a>" : "");
        # return "<a href=\"restart.cgi?$args\">$text{"lib_buttac"}</a><br>\n".
        #     "<a href=\"stop.cgi?$args\">$text{"lib_buttsd"}</a>\n";
    }
    else {
        return $access{'start'} ?
            "<a href='start.cgi?" . $args . "'>" . $text{"index_button_start"} . "</a>" : "";
        # return "<a href=\"start.cgi?$args\">$text{"lib_buttsd1"}</a>\n";
    }
}

=head2 find_dnsmasq()
    Returns the path to the dnsmasq executable
=cut
sub find_dnsmasq{
    return $config{'dnsmasq_path'}
        if (-x &translate_filename($config{'dnsmasq_path'}) &&
            !-d &translate_filename($config{'dnsmasq_path'}));
    return undef;
}

=head2 get_pid_file()
    Returns the path to the PID file (without any translation)
=cut
sub get_pid_file{
    return $config{'pid_filename'} if ($config{'pid_filename'});
    local $pidfilestr = $dnsmconfig->{"pid-file"}->{"val"};
    return $pidfile = $pidfilestr ? $pidfilestr : "/var/run/dnsmasq/dnsmasq.pid";
}

=head2 restart_dnsmasq()
    Re-starts DNSMasq, and returns undef on success or an error message on failure
=cut
sub restart_dnsmasq {
    if ($config{'dnsmasq_restart'} eq 'restart') {
        # Call stop and start functions
        local $err = &stop_dnsmasq();
        return $err if ($err);
        local $stopped = &wait_for_dnsmasq_stop();
        local $err = &start_dnsmasq();
        return $err if ($err);
    }
    elsif ($config{'dnsmasq_restart'}) {
        # Use the configured start command
        &clean_environment();
        local $out = &backquote_logged("$config{'dnsmasq_restart'} 2>&1");
        &reset_environment();
        if ($?) {
            return "<pre>".&html_escape($out)."</pre>";
        }
    }
    &restart_last_restart_time();
    return undef;
}

=head2 reload_dnsmasq_files()
    Clears DNSMasq cache and then re-loads /etc/hosts and /etc/ethers and any file given by 'dhcp-hostsfile',  
    'dhcp-hostsdir', 'dhcp-optsfile', 'dhcp-optsdir', 'addn-hosts', or 'hostsdir'. The DHCP lease change script
    is called for all existing DHCP leases. If 'no-poll' is set, also re-reads /etc/resolv.conf. Does NOT
    re-read the configuration file. Returns undef on success or an error message on failure
=cut
sub reload_dnsmasq_files {
    if ($config{'dnsmasq_reload_files'}) {
        # Use the configured start command
        &clean_environment();
        local $out = &backquote_logged("$config{'dnsmasq_reload_files'} 2>&1");
        &reset_environment();
        if ($?) {
            return "<pre>".&html_escape($out)."</pre>";
        }
    }
    else {
        # send SIGHUP directly
        local $pidfile = &get_pid_file();
        &open_readfile(PID, $pidfile) || return &text('restart_epid', $pidfile);
        <PID> =~ /(\d+)/ || return &text('restart_epid2', $pidfile);
        close(PID);
        &kill_logged('HUP', $1) || return &text('restart_esig', $1);
    }
    &restart_last_restart_time();
    return undef;
}

=head2 dump_log()
    Generate a complete cache dump, and returns undef on success or an error message on failure
=cut
sub dump_log {
    if ($config{'dnsmasq_dump_log'}) {
        # Use the configured start command
        &clean_environment();
        local $out = &backquote_logged("$config{'dnsmasq_dump_log'} 2>&1");
        &reset_environment();
        if ($?) {
            return "<pre>".&html_escape($out)."</pre>";
        }
    }
    else {
        # send SIGUSR1 directly
        local $pidfile = &get_pid_file();
        &open_readfile(PID, $pidfile) || return &text('restart_epid', $pidfile);
        <PID> =~ /(\d+)/ || return &text('restart_epid2', $pidfile);
        close(PID);
        &kill_logged('USR1', $1) || return &text('restart_esig', $1);
    }
    return undef;
}

=head2 rotate_log()
    When logging to a file, DNSMasq will close and reopen the file; returns undef on success or an error message on failure
=cut
sub rotate_log {
    # send SIGUSR2 directly
    local $pidfile = &get_pid_file();
    &open_readfile(PID, $pidfile) || return &text('restart_epid', $pidfile);
    <PID> =~ /(\d+)/ || return &text('restart_epid2', $pidfile);
    close(PID);
    &kill_logged('USR2', $1) || return &text('restart_esig', $1);
    return undef;
}

=head2 stop_dnsmasq()
    Attempts to stop the running DNSMasq process, and returns undef on success or
    an error message on failure
=cut
sub stop_dnsmasq {
    local $out;
    if ($config{'dnsmasq_stop'}) {
        # use the configured stop command
        $out = &backquote_logged("($config{'dnsmasq_stop'}) 2>&1");
        if ($?) {
            return "<pre>".&html_escape($out)."</pre>";
        }
    }
    else {
        # kill the process
        $pidfile = &get_pid_file();
        open(PID, "<".$pidfile) || return &text('stop_epid', $pidfile);
        <PID> =~ /(\d+)/ || return &text('stop_epid2', $pidfile);
        close(PID);
        &kill_logged('TERM', $1) || return &text('stop_esig', $1);
    }
    return undef;
}

=head2 start_dnsmasq()
    Attempts to start DNSMasq, and returns undef on success or an error message
    upon failure.
=cut
sub start_dnsmasq {
    local ($out, $cmd);
    &clean_environment();
    if ($config{'dnsmasq_start'}) {
        # use the configured start command
        if ($config{'dnsmasq_stop'}) {
            # execute the stop command to clear lock files
            &system_logged("($config{'dnsmasq_stop'}) >/dev/null 2>&1");
        }
        $out = &backquote_logged("($config{'dnsmasq_start'}) 2>&1");
        &reset_environment();
        if ($?) {
            return "<pre>".&html_escape($out)."</pre>";
        }
    }
    else {
        # start manually
        local $dnsmasq = &find_dnsmasq();
        $cmd = "$dnsmasq -C $config{'config_file'}";
        local $temp = &transname();
        local $rv = &system_logged("( $cmd ) >$temp 2>&1 </dev/null");
        $out = &read_file_contents($temp);
        unlink($temp);
        &reset_environment();
    }
    # Check if DNSMasq may have failed to start
    local $slept;
    if ($out =~ /\S/ && $out !~ /dnsmasq\s+started/i) {
        sleep(3);
        if (!&is_dnsmasq_running()) {
            return "<pre>".&html_escape($cmd)." :\n".
                    &html_escape($out)."</pre>";
        }
        $slept = 1;
    }
    # # check if startup was successful.
    # sleep(3) if (!$slept);
    # local $conf = &get_config();
    # if (!&is_dnsmasq_running()) {
    #     # Not running..  find out why
    #     local $errorlogstr = &find_directive_struct("ErrorLog", $conf);
    #     local $errorlog = $errorlogstr ? $errorlogstr->{'words'}->[0]
    #                     : "logs/error_log";
    #     if ($out =~ /\S/) {
    #         return "$text{'start_eafter'} : <pre>$out</pre>";
    #     }
    #     elsif ($errorlog eq 'syslog' || $errorlog =~ /^\|/) {
    #         return $text{'start_eunknown'};
    #     }
    #     else {
    #         $errorlog = &server_root($errorlog, $conf);
    #         $out = `tail -5 $errorlog`;
    #         return "$text{'start_eafter'} : <pre>$out</pre>";
    #     }
    # }
    &restart_last_restart_time();
    return undef;
}

# Returns the process ID if DNSMasq is running
sub is_dnsmasq_running {
    my $dnsmconfig = &parse_config_file();

    # Find all possible PID files
    my @pidfiles;
    my $pidstruct = &find_config("pid-file", $dnsmconfig);
    push(@pidfiles, $pidstruct->{'val'}) if ($pidstruct);
    push(@pidfiles, split(/\s+/, $config{'pid_filename'})) if ($config{'pid_filename'});
    @pidfiles = grep { $_ ne "none" } @pidfiles;

    # Try check one
    foreach my $pidfile (@pidfiles) {
        my $pid = &check_pid_file($pidfile);
        return $pid if ($pid);
    }

    if (!@pidfiles) {
        # Fall back to checking for dnsmasq process
        my ($pid) = &find_byname("dnsmasq");
        return $pid;
    }

    return 0;
}

=head2 wait_for_dnsmasq_stop([secs])
    Wait 30 (by default) seconds for DNSMasq to stop. Returns 1 if OK, 0 if not
=cut
sub wait_for_dnsmasq_stop {
    local $secs = $_[0] || 30;
    for(my $i=0; $i<$secs; $i++) {
        return 1 if (!&is_dnsmasq_running());
        sleep(1);
    }
    return 0;
}

=head2 test_config()
    If possible, test the current configuration and return an error message,
    or undef.
=cut
sub test_config {
    # Test with dnsmasq
    local $dnsmasq = &find_dnsmasq();
    local $cmd = "\"$dnsmasq\" --test";
    local $out = &backquote_command("$cmd 2>&1");
    if ($out && $out !~ /syntax.*\s+ok/i) {
        return $out;
    }
    return undef;
}

=head2 update_last_config_change()
    Updates the flag file indicating when the config was changed
=cut
sub update_last_config_change {
    &open_tempfile(FLAG, ">$last_config_change_flag", 0, 1);
    &close_tempfile(FLAG);
}

=head2 restart_last_restart_time()
    Updates the flag file indicating when the config was changed
=cut
sub restart_last_restart_time {
    &open_tempfile(FLAG, ">$last_restart_time_flag", 0, 1);
    &close_tempfile(FLAG);
}

=head2 needs_config_restart()
    Returns 1 if a restart is needed for sure after a config change
=cut
sub needs_config_restart {
    my @cst = stat($last_config_change_flag);
    my @rst = stat($last_restart_time_flag);
    if (@cst && @rst && $cst[9] > $rst[9]) {
        return 1;
    }
    return 0;
}

# Returns HTML for a link to put in the top-right corner of every page
sub rotate_logs_button {
    return undef if ($config{'restart_pos'} == 2);
    my $args = "redir=".&urlize(&this_url());
    if (&is_dnsmasq_running()) {
        return ($access{'restart'} ?
            "<a href='log_rotate.cgi?" . $args . "'>" . $text{"lib_buttac"} . "</a>" : "");
    }
}

# Returns the structure(s) with some name
# disabled mode 0 = only enabled, 1 = both, 2 = only disabled,
# 3 = disabled and tags
sub find_config {
    my ($name, %conf, $mode) = @_;
    $mode ||= 0;
    my @rv;
    my $c;
    my $k;
    while (($k,$c) = each (%conf)) {
        if ($c->{'name'} eq $name) {
            push(@rv, $c);
        }
    }
    if ($mode == 0) {
        @rv = grep { $_->{'enabled'} && !$_->{'tag'} } @rv;
    }
    elsif ($mode == 1) {
        @rv = grep { !$_->{'tag'} } @rv;
    }
    elsif ($mode == 2) {
        @rv = grep { !$_->{'enabled'} && !$_->{'tag'} } @rv;
    }
    elsif ($mode == 3) {
        @rv = grep { !$_->{'enabled'} } @rv;
    }
    return @rv ? wantarray ? @rv : $rv[0]
            : wantarray ? () : undef;
}

=head2 update(lineno, text, file_arr_ref, action)
    update the config file array
        lineno       - the line number (array index) to update; -1 to add
        text         - the new contents of the line
        file_arr_ref - reference to the array to change
        action       - 0 = normal
                       1 = put a comment marker ('#') at start of line
                       2 = delete the line

=cut
sub update {
    my ($lineno, $text, $file_arr_ref, $action) = @_;
    my $line;

    if ($action == 2) {
        if ($lineno >= 0) {
            splice(@$file_arr_ref, $lineno - 1, 1);
        }
    }
    else {
        $line = $text eq "" ? @$file_arr_ref[$lineno - 1] : $text;
        # always start with uncommented, then comment if needed
        $line =~ s/^#*\s*//g ;
        if ( $action == 1 ) {
            $line = "#" . $line;
        }
        # elsif ( $action == 0 ) {
        #     $line =~ s/^#*//g ;
        # }
        if ( $lineno < 0 ) {
            push @$file_arr_ref, $line;
        }
        else {
            @$file_arr_ref[$lineno - 1]=$line;
        }
    }
} # end of sub update

=head2 update_selected(configfield, action, selected_idxes, dnsmconfig)
    update multiple selected items
    When changing (enable, disable, delete) multiple items, we don't want to keep
    opening a config file, changing one item, and then closing it. Because there
    could be both multiple files and many selected items, it's more efficient to open
    each file, make all changes that correspond to just that file, and then close it.
        configfield    - dnsmasq option name
        action         - enable, disable, delete
        selected_idxes - array reference of selected item indexes
        dnsmconfig     - reference to full config hash
=cut
sub update_selected {
    my ($configfield, $action, $selected_idxes, $dnsmconfig) = @_;
    my @conf_filenames;
    my $actioncode = $action eq "enable" ? 0 : $action eq "disable" ? 1 : $action eq "delete" ? 2 : -1;
    foreach my $selected_idx (@$selected_idxes) {
        my $sourcefile = $dnsmconfig{$configfield}[$selected_idx]->{"file"};
        if (! grep { /^$sourcefile$/ } ( @conf_filenames ) ) {
            push @conf_filenames, $sourcefile;
        }
    }
    foreach my $conf_filename (@conf_filenames) {
        my $file_arr = &read_file_lines($conf_filename);
        # if deleting - since we're using index - they must be handled in reverse
        # if not deleting, it doesn't matter
        my @reversed_selected_idxes = reverse @$selected_idxes;
        foreach my $selected_idx (@reversed_selected_idxes) {
            my $item = $dnsmconfig{$configfield}[$selected_idx];
            if ($item->{"file"} eq $conf_filename) {
                &update( $item->{"line"}, "",
                    \@$file_arr, $actioncode );
            }
        }
        &flush_file_lines();
    }
}

sub internal_to_config {
    my $c = @_[0];
    $c =~ s/_/-/g ;
    return $c;
}

sub config_to_internal {
    my $i = @_[0];
    $i =~ s/-/_/g ;
    return $i;
}

sub update_booleans {
    my $result;
    my ( $all, $enabled, $dnsmconfig ) = @_;
    my @conf_filenames = ();
    foreach my $configfield ( @$all ) {
        # $result .= $configfield . ":" . $dnsmconfig{"$configfield"};
        my $sourcefile = $dnsmconfig{"$configfield"}->{"file"};
        if ( ! grep { /^$sourcefile$/ } ( @conf_filenames ) ) {
            push @conf_filenames, $sourcefile;
        }
    }
    foreach my $conf_filename ( @conf_filenames ) {
        my $file_arr = &read_file_lines($conf_filename);
        foreach my $configfield ( @$all ) {
            my $item = $dnsmconfig{"$configfield"};
            if ($item->{"file"} eq $conf_filename) {
                &update( $item->{"line"}, $configfield,
                    \@$file_arr, ( ( grep { /^$configfield$/ } ( @$enabled ) ) ? 0 : 1 ) );
            }
        }
        &flush_file_lines();
    }
    return $result;
}

sub update_simple_vals {
    my $result;
    my ( $all, $enabled, $dnsmconfig ) = @_;
    my @conf_filenames = ();
    foreach my $configfield ( @$all ) {
        my $sourcefile = $dnsmconfig{"$configfield"}->{"file"};
        if ( ! grep { /^$sourcefile$/ } ( @conf_filenames ) ) {
            push @conf_filenames, $sourcefile;
        }
    }
    foreach my $conf_filename ( @conf_filenames ) {
        my $file_arr = &read_file_lines($conf_filename);
        foreach my $configfield ( @$all ) {
            my $internalfield = &config_to_internal($configfield);
            my $item = $dnsmconfig{"$configfield"};
            if ($item->{"file"} eq $conf_filename && ($item->{"val_optional"} || $in{$internalfield . "val"}  ) ) {
                &update( $item->{"line"}, "$configfield" . ( $in{$internalfield . "val"} eq "" ? "" : "=" . $in{$internalfield . "val"}),
                    \@$file_arr, ( ( grep { /^$configfield$/ } ( @$enabled ) ) ? 0 : 1 ) );
            }
        }
        &flush_file_lines();
    }
}

sub apply_simple_vals {
    my ($domain, $sel, $page) = @_;
    my @bools = ();
    my @singles = ();
    my @domain_array = $domain eq "dns" ? @confdns : $domain eq "dhcp" ? @confdhcp : @conft_b_p;
    foreach my $configfield ( @domain_array ) {
        next if ( grep { /^$configfield$/ } ( @confarrs ) );
        next if ( %dnsmconfigvals{"$configfield"}->{"mult"} ne "" );
        next if ( %dnsmconfigvals{"$configfield"}->{"page"} ne $page );
        if ( grep { /^$configfield$/ } ( @confbools ) ) {
            push @bools, $configfield;
        }
        elsif ( grep { /^$configfield$/ } ( @confsingles ) ) {
            push @singles, $configfield;
        }
    }

    # check user input for obvious errors
    foreach my $configfield ( @singles ) {
        my $item = $dnsmconfig{"$configfield"};
        my $internalfield = &config_to_internal($configfield);
        if ( grep { /^$internalfield$/ } ( @{$sel} )) {
            if ( ! $item->{"val_optional"} && $in{$internalfield . "val"} eq "" ) {
                &send_to_error( $configfield, $text{"err_valreq"}, $returnto, $returnlabel );
            }
            if ( $in{$internalfield . "val"} ne "" ) {
                my $item_template = %dnsmconfigvals{"$configfield"};
                if ( $item_template->{"valtype"} eq "int" && ($in{$internalfield . "val"} !~ /^$NUMBER$/) ) {
                    &send_to_error( $configfield, $text{"err_numbbad"}, $returnto, $returnlabel );
                }
                elsif ( $item_template->{"valtype"} eq "file" && ($in{$internalfield . "val"} !~ /^$FILE$/) ) {
                    &send_to_error( $configfield, $text{"err_filebad"}, $returnto, $returnlabel );
                }
                elsif ( $item_template->{"valtype"} eq "path" && ($in{$internalfield . "val"} !~ /^$FILE$/) ) {
                    &send_to_error( $configfield, $text{"err_pathbad"}, $returnto, $returnlabel );
                }
                elsif ( $item_template->{"valtype"} eq "dir" && ($in{$internalfield . "val"} !~ /^$FILE$/) ) {
                    &send_to_error( $configfield, $text{"err_pathbad"}, $returnto, $returnlabel );
                }
            }
        }
    }
    # adjust everything to what we got

    &update_booleans( \@bools, $sel, \%dnsmconfig );

    &update_simple_vals( \@singles, $sel, \%$dnsmconfig );
}

sub check_other_vals {
    my ($domain, $sel) = @_;
    my @vars = ();
    my @domain_array = $domain eq "dns" ? @confdns : $domain eq "dhcp" ? @confdhcp : @conft_b_p;
    foreach my $configfield ( @domain_array ) {
        next if ( grep { /^$configfield$/ } ( @confarrs ) );
        next if ( %dnsmconfigvals{"$configfield"}->{"mult"} ne "" );
        if ( grep { /^$configfield$/ } ( @confvars ) ) {
            push @vars, $configfield;
        }
    }

    # check user input for obvious errors
    foreach my $configfield ( @vars ) {
        my $item = $dnsmconfig{"$configfield"};
        my $internalfield = &config_to_internal($configfield);
        if ( grep { /^$internalfield$/ } ( @{$sel} )) {
            my @otherfields = ();
            foreach my $key ( @{ %configfield_fields{$internalfield}->{"param_order"} } ) {
                my $definition = %configfield_fields{$internalfield}->{$key};
                push ( @otherfields, $internalfield . "_" . $key );
                # if this parameter is an array, include
                if ( $definition->{"required"} && $in{$internalfield  . "_" . $key} eq "" ) {
                    &send_to_error( $configfield, $text{"err_valreq"}, $returnto, $returnlabel );
                }
                if ( $in{$internalfield . "_" . $key} ne "" ) {
                    if ( $definition->{"valtype"} eq "int" && ($in{$internalfield . "_" . $key} !~ /^$NUMBER$/) ) {
                        &send_to_error( $configfield, $text{"err_numbbad"}, $returnto, $returnlabel );
                    }
                    elsif ( $definition->{"valtype"} eq "file" && ($in{$internalfield . "_" . $key} !~ /^$FILE$/) ) {
                        &send_to_error( $configfield, $text{"err_filebad"}, $returnto, $returnlabel );
                    }
                    elsif ( $definition->{"valtype"} eq "path" && ($in{$internalfield . "_" . $key} !~ /^$FILE$/) ) {
                        &send_to_error( $configfield, $text{"err_pathbad"}, $returnto, $returnlabel );
                    }
                    elsif ( $definition->{"valtype"} eq "dir" && ($in{$internalfield . "_" . $key} !~ /^$FILE$/) ) {
                        &send_to_error( $configfield, $text{"err_pathbad"}, $returnto, $returnlabel );
                    }
                }
            }
        }
    }
}

=head2 add_to_list( configfield, val )
  Adds a new entry value to the configuration
=cut
sub add_to_list {
    my ( $configfield, $val ) = @_;
    my $cfn = $config{config_file};
    if (@{$dnsmconfig{$configfield}} > 0) {
        $cfn = $dnsmconfig{$configfield}[0]->{"file"};
    }
    my $cf = &read_file_lines($cfn);
    &update(-1, "$configfield=$val", \@$cf, 0);
    &flush_file_lines();

}

sub send_to_error {
    my ($line, $err_type, $returnto, $returnlabel) = @_;
    my $line = "error.cgi?line=" . &urlize($line);
    $line .= "&type=" . &urlize($err_type);
    $line .= "&returnto=" . $returnto;
    $line .= "&returnlabel=" . &urlize($returnlabel);
    &redirect( $line );
    exit;
}

sub this_url {
    my $url = $ENV{'SCRIPT_NAME'};
    if (defined($ENV{'QUERY_STRING'})) {
        $url .= "?$ENV{'QUERY_STRING'}";
    }
    return $url;
}

# list_auth_users(file)
sub list_auth_users {
    my ($file) = @_;
    my @rv;
    my $lnum = 0;
    my $fh = "USERS";
    &open_readfile($fh, $file);
    while(<$fh>) {
        if (/^(#*)([^:]+):(\S+)/) {
            push(@rv, { 'user' => $2, 'pass' => $3,
                    'enabled' => !$1, 'line' => $lnum });
            }
        $lnum++;
    }
    close($fh);
    if ($config{'sort_conf'}) {
        return sort { $a->{'user'} cmp $b->{'user'} } @rv;
    }
    else {
        return @rv;
    }
}

# can_access(file)
sub can_access {
    my ($file) = @_;
    my @f = grep { $_ ne '' } split(/\//, $file);
    return 1 if ($access{'root'} eq '/');
    my @a = grep { $_ ne '' } split(/\//, $access{'root'});
    for(my $i=0; $i<@a; $i++) {
        return 0 if ($a[$i] ne $f[$i]);
    }
    return 1;
}

sub select_none_link {
    return &theme_select_none_link(@_) if (defined(&theme_select_none_link));
    my ($field, $form, $text) = @_;
    $form = int($form);
    $text ||= $text{'ui_selnone'};
    # return "<a class='select_none' href='#' onClick='javascript:var ff = document.forms[$form].$field; ff.checked = false; for(i=0; i<ff.length; i++) { if (!ff[i].disabled) { ff[i].checked = false; } } return false;'><i class='fa fa-fw fa-square-o'> </i>$text</a>";
    # if (defined(&theme_select_all_link) && defined(&theme_select_invert_link)) {
    #     return "<a class='select-none' href='#' onClick='javascript:theme_select_all_link($form, \"$field\"); theme_select_invert_link($form, \"$field\"); return false;'>$text</a>";
    # }
    # else {
    #     return "<a class='select-none' href='#' onClick='javascript:select_all_link($form, \"$field\"); select_invert_link($form, \"$field\"); return false;'>$text</a>";
    # }
    my $output = "<a class='select-none' href='#' onClick='javascript:theme_select_all_link($form, \"$field\"); theme_select_invert_link($form, \"$field\"); return false;'>";
    $output .= "$text</a>";
    return $output;
}

sub list_links {
    my ($sel_name, $form) = @_;
    my $addcgi = defined($_[2]) ? $_[2] : undef;
    my $what = defined($_[3]) ? $_[3] : undef;
    my $where = defined($_[4]) ? $_[4] : undef;
    my $link_text = defined($_[5]) ? $_[5] : undef;
    my @links = ( );
    push(@links, &select_all_link($sel_name, $form),
                &select_none_link($sel_name, $form),
                &select_invert_link($sel_name, $form)
                );
    if (defined($addcgi)) {
        push(@links, &ui_link("$addcgi?new=1&what=$what&where=$where",$link_text));
    }
    return @links;
}

sub list_links_add_popup {
    my ($sel_name, $form) = @_;
    my $addcgi = defined($_[2]) ? $_[2] : undef;
    my $height = defined($_[3]) ? $_[3] : 300;
    my $fieldmapping = defined($_[4]) ? $_[4] : undef;
    my @links = ( );
    push(@links, &select_all_link($sel_name, $form),
                &select_none_link($sel_name, $form),
                &select_invert_link($sel_name, $form)
                );
    if (defined($addcgi)) {
        # popup_window_button(url, width, height, scrollbars?, &field-mappings)
        push(@links, &popup_window_button("$addcgi", 600, $height, 0, \@fieldmapping ));
    }
    return @links;
}

=head2 get_mover_buttons(url, current_index, total_items)
=cut
sub get_mover_buttons {
    my ($url, $current_index, $total) = @_;
    my $sep = $url =~ /\?/ ? "&" : "?";
    my $mover;
    if ( $total == 1 ) {
        return "<img src=images/gap.gif>";
    }
    if( $current_index == ($total - 1) ) {
        $mover = "<img src=images/gap.gif>";
    }
    else {	
        $mover = "</a><a href='$url" . $sep . "idx=$current_index&t=".$total."&dir=down'><img src=images/down.gif border=0/></a>";
        # $mover = "<span onclick=\"location.href='$url" . $sep . "idx=$current_index&t=".$total."&dir=down';return false;\"><img src=images/down.gif border=0/></span>";
    }
    if( $current_index == 0 ) {
        $mover .= "<img src=images/gap.gif>";
    }
    else {
        $mover .= "<a href='$url" . $sep . "idx=$current_index&t=".$total."&dir=up'><img src=images/up.gif border=0/></a>";
        # $mover .= "<span onclick=\"location.href='$url" . $sep . "idx=$current_index&t=".$total."&dir=up';return false;\"><img src=images/up.gif border=0/></span>";
    }
    return $mover;
}

=head2 add_file_chooser_button(text, input, type, formid, [chroot], [addmode])
    Return HTML for a button that pops up a file chooser when clicked, and places
    the selected filename into another HTML field. The parameters are :
        text - Text to appear in the button.
        input - Name of the form field to store the filename in.
        type - 0 for file or directory chooser, or 1 for directory only.
        formid - Id of the form containing the button.
        chroot - If set, the chooser will be limited to this directory.
        addmode - If set to 1, the selected filename will be appended to the text box instead of replacing its contents.
=cut
sub add_file_chooser_button {
    my ($button_text, $input, $type, $formid)  = @_;
    my $chroot = defined($_[4]) ? $_[4] : "/";
    my $add    = int($_[5]);
    my $link   = "chooser.cgi?add=$add&type=$type&chroot=$chroot&file=\"+encodeURIComponent(ifield.value)";

    my $file_chooser_button = "<button class='btn btn-inverse btn-tiny file-chooser-button chooser_button' ";
    $file_chooser_button .= "style='min-width:90px; width:auto; height:33px;' onClick='ifield = \$( \"#$input\" )[0]; ";
    $file_chooser_button .= "chooser = window.open(\"$theme_webprefix/$link, \"chooser\"); chooser.ifield = ifield; window.ifield = ifield;'>";
    $file_chooser_button .= "$button_text</button>\n";

    my $hidden_input_fields = "";
    $hidden_input_fields .= "<input type=\"hidden\" name=\"$input\" class=\"new-file-input\"></input>";
    $hidden_input_fields .= "";
    return ($file_chooser_button, $hidden_input_fields);
}

=head2 edit_file_chooser_link(text, input, type, current_value, idx, formid, [chroot], [addmode])
    Return HTML for a link that pops up a file chooser when clicked, and places
    the selected filename into hidden HTML text field. The parameters are :
        text - Text to appear in the link.
        input - Name of the form field to store the filename in.
        type - 0 for file or directory chooser, or 1 for directory only.
        current_value - Current filename/directory
        idx - Index of the item to edit
        formid - Id of the form containing the button.
        chroot - If set, the chooser will be limited to this directory.
        addmode - If set to 1, the selected filename will be appended to the text box instead of replacing its contents.
=cut
sub edit_file_chooser_link {
    my ($link_text, $input, $type, $current_value, $idx, $formid)  = @_;
    my $chroot = defined($_[6]) ? $_[6] : "/";
    my $add    = int($_[7]);
    my $link   = "chooser.cgi?add=$add&type=$type&chroot=$chroot&file=\"+encodeURIComponent(ifield.value)";

    if ($link_text eq "") {
        $link_text = "<span style='color: #595959 !important; font-style: italic;'>" . $text{"empty_value"} . "</span>"
    }

    my $file_edit_link = "<a href=\"#\" onclick='event.preventDefault();"
        . $formid."_".$input."_temp = \"".$current_value."\";"
        . "\$(\"input[name=" . $input. "]\").val(\"".$current_value."\");"
        . "\$(\"input[name=" . $input. "_idx]\").val($idx);"
        . "\$(\"#" . $formid . "_" . $input. "_b\").trigger(\"click\");event.stopPropagation();return false;'>" . $link_text . "</a>";

    my $hidden_input_fields = "<input type=\"hidden\" name=\"$input\"></input>"
        . "<button class='btn file-chooser-button chooser_button hidden' id=\"" . $formid . "_" . $input. "_b\""
        . "style='min-width:90px; width:auto; height:33px;' onClick='ifield = \$( \"#$input\" )[0]; "
        . "chooser = window.open(\"" . $theme_webprefix . "/" . $link . ", \"chooser\"); chooser.ifield = ifield; window.ifield = ifield;'>"
        . "</button>\n"
        . "";
    $hidden_input_fields .= "<input type=\"hidden\" name=\"".$input."_idx\"></input>";

    my $submit_script = "<script>";
    # $submit_script .= $formid."_".$input."_intvl = setInterval(function() {\n\tif(\$( \"#$input\" ).val()) {\n\t\tclearInterval(".$formid."_".$input."_intvl);\n\t\tdelete ".$formid."_".$input."_intvl;\n\t\tsetTimeout(function() {\n\t\t\t\$( \"#$formid\" ).submit();\n\t\t\t\$( \"#$input\" ).val('');\n\t\t}, 0);\n\t}\n}, 50);";
    $submit_script .= "".$formid."_".$input."_temp = '';\n";
    $submit_script .= "var " . $formid."_".$input."_intvl = setInterval(function() {\n\t\$(\"input[name=$input]\").each(function(){\n\t\tif(\$(this).val()!=".$formid."_".$input."_temp) {\n\t\t\tclearInterval(".$formid."_".$input."_intvl);\n\t\t\tdelete ".$formid."_".$input."_intvl;\n\t\t\tsetTimeout(function() {\n\t\t\t\t\$( \"#".$formid."\" ).submit();\n\t\t\t\t\$(this).val('');\n\t\t\t\t".$formid."_".$input."_temp='';\n\t\t}, 0);\n\t\t}\n\t});\n}, 50);";
    # $submit_script .= "var " . $formid."_".$input."_intvl = setInterval(function() {\n\t\$(\"input[name=$input]\").each(function(){\n\t\tif(\$(this).val()!=".$formid."_".$input."_temp) {\n\t\t\tclearInterval(".$formid."_".$input."_intvl);\n\t\t\tdelete ".$formid."_".$input."_intvl;\n\t\t\tsetTimeout(function() {\n\t\t\t\t\n\t\t\t\t\$(this).val('');\n\t\t\t\t".$formid."_".$input."_temp='';\n\t\t}, 0);\n\t\t}\n\t});\n}, 50);";
    $submit_script .= "</script>";
    return ($file_edit_link, $hidden_input_fields, $submit_script);
}

=head2 add_interface_chooser_button(text, input, formid, [addmode])
    Return HTML for a button that pops up an interface chooser when clicked, and places
    the selected filename into another HTML field. The parameters are :
        text - Text to appear in the button.
        input - Name of the form field to store the filename in.
        formid - Id of the form containing the button.
        addmode - If set to 1, the selected interface will be appended to the text box instead of replacing its contents.
=cut
sub add_interface_chooser_button {
    my ($button_text, $input, $formid)  = @_;
    my $add    = int($_[3]);
    my $link   = "net/interface_chooser.cgi?multi=$add&interface=";

    my $iface_chooser_button = "<button class='btn btn-inverse btn-tiny iface-chooser-button chooser_button' ";
    $iface_chooser_button .= "style='min-width:90px; width:auto; height:33px;' onClick='ifield = \$( \"#$input\" )[0]; ";
    $iface_chooser_button .= "chooser = window.open(\"$theme_webprefix/$link, \"chooser\"); chooser.ifield = ifield; window.ifield = ifield; ";
    $iface_chooser_button .= "'>$button_text</button>\n";

    my $hidden_input_fields = "";
    $hidden_input_fields .= "<input type=\"hidden\" name=\"$input\" class=\"new-iface-input\"></input>";
    $hidden_input_fields .= "";
    return ($iface_chooser_button, $hidden_input_fields);
}

=head2 edit_interface_chooser_link(text, input, type, current_value, idx, formid, [addmode])
    Return HTML for a link that pops up an interface chooser when clicked, and places
    the selected interface into hidden HTML text field. The parameters are :
        text - Text to appear in the link.
        input - Name of the form field to store the interface in.
        current_value - Current interface
        idx - Index of the item to edit
        formid - Id of the form containing the button.
        addmode - If set to 1, the selected interface will be appended to the text box instead of replacing its contents.
=cut
sub edit_interface_chooser_link {
    my ($link_text, $input, $current_value, $idx, $formid)  = @_;
    my $add = $_[5];
    my $link   = "net/interface_chooser.cgi?multi=$add&interface=";

    if ($link_text eq "") {
        $link_text = "<span style='color: #595959 !important; font-style: italic;'>" . $text{"empty_value"} . "</span>"
    }

    my $iface_edit_link = "<a href=\"#\" onclick='event.preventDefault();"
        . $formid."_".$input."_temp = \"".$current_value."\";"
        . "\$(\"input[name=" . $input. "]\").val(\"".$current_value."\");"
        . "\$(\"input[name=" . $input. "_idx]\").val($idx);"
        . "\$(\"#" . $formid . "_" . $input. "_b\").trigger(\"click\");event.stopPropagation();return false;'>" . $link_text . "</a>";

    my $hidden_input_fields = "<input type=\"hidden\" name=\"$input\"></input>"
        . "<button class='btn btn-inverse btn-tiny iface-chooser-button chooser_button hidden' id=\"" . $formid . "_" . $input. "_b\""
        . "style='min-width:90px; width:auto; height:33px;' onClick='ifield = \$( \"#$input\" )[0]; "
        . "chooser = window.open(\"" . $theme_webprefix . "/" . $link . ", \"chooser\"); chooser.ifield = ifield; window.ifield = ifield;'>"
        . "</button>\n"
        . "";
    $hidden_input_fields .= "<input type=\"hidden\" name=\"".$input."_idx\"></input>";

    my $submit_script = "<script>";
    $submit_script .= "".$formid."_".$input."_temp = '';\n";
    $submit_script .= "var " . $formid."_".$input."_intvl = setInterval(function() {\n\t\$(\"input[name=$input]\").each(function(){\n\t\tif(\$(this).val()!=".$formid."_".$input."_temp) {\n\t\t\tclearInterval(".$formid."_".$input."_intvl);\n\t\t\tdelete ".$formid."_".$input."_intvl;\n\t\t\tsetTimeout(function() {\n\t\t\t\t\$( \"#".$formid."\" ).submit();\n\t\t\t\t\$(this).val('');\n\t\t\t\t".$formid."_".$input."_temp='';\n\t\t}, 0);\n\t\t}\n\t});\n}, 50);";
    $submit_script .= "</script>";
    return ($iface_edit_link, $hidden_input_fields, $submit_script);
}

=head2 edit_item_popup_modal_link(url, internalfield, formid, link_text)
    Returns HTML for a link that will popup, hidden fields, and some JS to handle it 
    for a simple edit window of some kind.
        url - Base URL of the popup window's contents
        internalfield - Keyword that identifies what to edit
        formid - Id of the form on the source page to submit
        link_text - Text to appear in link
=cut
sub edit_item_popup_modal_link {
    my ($url, $internalfield, $formid, $link_text) = @_;

    my $sep = $url =~ /\?/ ? "&" : "?";
    $url .= $sep . "internalfield=$internalfield";
    $url .= "&formid=" . $formid;

    if ($link_text eq "") {
        $link_text = "<span style='color: #595959 !important; font-style: italic;'>" . $text{"empty_value"} . "</span>"
    }

    my $link = "<a data-toggle=\"modal\" href=\"$url\" data-target=\"#list-item-edit-modal\" data-backdrop=\"static\">";
    $link .= "$link_text";
    $link .= "</a>";
    return $link;
}

=head2 edit_item_link(link_text, internalfield, title, idx, formid, field-mappings[, extra-url-params])
    Returns HTML for a link that will popup, hidden fields, and some JS to handle it 
    for a simple edit window of some kind.
        link_text - Text to appear in link
        internalfield - Keyword that identifies what to edit
        title - Text to appear in the popup window title
        idx - Index of the item to edit
        formid - Id of the form on the source page to submit
        field-mappings - Array of fields to include in form
        [extra-url-params] - URL-formatted string of any extra param=value pairs (if multiple, delimited with "&")
=cut
sub edit_item_link {
    my ($link_text, $internalfield, $title, $idx, $formid, $fields) = @_;
    my $extra_url_params = @_[6] || "";
    if ($extra_url_params) {
        $extra_url_params = ( $extra_url_params =~ /^&/ ? "" : "&" ) . $extra_url_params;
    }

    $title =~ s/ /+/g ;
    my $qparams = "action=edit&idx=$idx&title=$title" . $extra_url_params;
    my $link = &edit_item_popup_modal_link("list_item_edit_chooser.cgi?" . $qparams, $internalfield, $formid, $link_text);

    my $hidden_input_fields = "<div>\n";
    foreach my $fieldname ( @$fields ) {
        $hidden_input_fields .= "<input type=\"hidden\" name=\"" . $internalfield . "_" . $fieldname . "\" class=\"edit-item-val\"></input>";
    }
    $hidden_input_fields .= "</div>\n";

    # my $edit_script = "<script>\n"
    #     . "function submit_" . $formid . "(vals) {\n"
    #     . "  vals.forEach((o) => {\n"
    #     . "    let f=o.f;let v=o.v;\n"
    #     . "    \$(\"#" . $formid . " input[name=\"+f+\"]\").val(v);\n"
    #     . "  });\n"
    #     . "  \$(\"#" . $formid . "\").submit();\n"
    #     . "}\n"
    #     . "</script>\n";
    # return ($link, $hidden_input_fields, $edit_script);
    return ($link, $hidden_input_fields);
}

=head2 add_item_popup_modal_button(url, internalfield, formid, button_content)
    Returns HTML for a button that will popup a simple list item add window of some kind.
    url - Base URL of the popup window's contents
    internalfield - Keyword that identifies what to add; handling must be defined in list_item_add_popup.cgi
    formid - Id of the form on the source page to submit
    button_content - Text to appear in button
=cut
sub add_item_popup_modal_button {
    my ($url, $internalfield, $formid, $button_content) = @_;

    my $sep = $url =~ /\?/ ? "&" : "?";
    $url .= $sep . "internalfield=$internalfield";
    $url .= "&formid=$formid";
    my $rv = "<a data-toggle=\"modal\" href=\"$url\" data-target=\"#list-item-edit-modal\" data-backdrop=\"static\" class='btn btn-inverse btn-tiny add-item-button new-dnsm-button-container' ";
    $rv .= ">";
    $rv .= "$button_content";
    $rv .= "</a>";
    return $rv;
}

=head2 add_item_button(buttontext, internalfield, title, formid, field-mappings[, extra-url-params])
    Returns HTML for a button that will popup a window, hidden fields, and some JS to handle it 
    for entry of a new item of some kind.
        buttontext - Text to appear in button
        internalfield - Keyword that identifies what to add; handling must be defined in list_item_add_popup.cgi
        title - Text to appear in the popup window title
        formid - Id of the form on the source page to submit
        fields - Array reference of field names i.e., [ "new_tag", "new_vendorclass" ]; must be handled in form's submit target
=cut
sub add_item_button {
    my ($button_text, $internalfield, $title, $formid, $fields) = @_;
    my $extra_url_params = @_[5] || "";
    if ($extra_url_params) {
        $extra_url_params = ( $extra_url_params =~ /^&/ ? "" : "&" ) . $extra_url_params;
    }

    # my @fieldmapping = ();
    my $hidden_input_fields = "<div>\n";
    foreach my $fieldname ( @$fields ) {
        $hidden_input_fields .= "<input type=\"hidden\" name=\"new_" . $internalfield . "_" . $fieldname . "\" class=\"add-item-val\"></input>";
    #     push( @fieldmapping, [ $fieldname, $fieldname ] );
    }
    $hidden_input_fields .= "</div>\n";

    $title =~ s/ /+/g ;
    my $qparams = "action=add&title=$title" . $extra_url_params;
    my $button = &add_item_popup_modal_button("list_item_edit_chooser.cgi?" . $qparams, $internalfield, $formid, $button_text );
    return ($button, $hidden_input_fields);
}

sub ui_selectbox_with_controls {
    my ($name, $values, $size, $length, $template) = @_;
    # my $minwidth = ((($length * 7.39) + 111) || "150") . "px";
    my $s = "<div>";
    # ui_select(name, value|&values, &options, [size], [multiple], [add-if-missing], [disabled?], [javascript])
    $s .= &ui_select( $name, undef, \@{ $values }, $size, 1, undef, 0, "id=\"$name\"" );
    $s .= "<script type='text/javascript'>\n"
        . "\$(document).ready(function() {\n"
        . "  setTimeout(function() {\n"
        # . "    \$(\"select[name='$name']\").attr(\"style\", (i,v)=>{ return (v?v:'')+\"min-width: $minwidth;\"; });\n"
        . "    \$(\"select[name='$name']\").attr(\"style\", (i,v)=>{ return (v?v:'')+\"width: 100%;\"; });\n"
        . "  }, 10);\n"
        . "});\n"
        . "\$(\"select[name='$name']\").parents(\"form\").first().on(\"submit\", function(e){ \$(\"select[name='$name'] option\").prop('selected', true); });\n"
        . "</script>";
    $s .= "<br><nobr><div><span class=\"btn btn-tiny remove-item-button-small\" onclick=\"removeSelectItem('$name'); return false;\"></span>";
    # ui_textbox(name, value, size, [disabled?], [maxlength], [tags])
    my $textbox_name = $name . "_additem";
    $s .= &ui_textbox( $textbox_name, undef, $length, undef, undef, "placeholder=\"$template\" title=\"$template\"" );
    $s .= "<span class=\"btn btn-tiny add-item-button-small\" onclick=\"addItemToSelect('$name'); return false;\"></span>";
    $s .= "</div></nobr>";
    $s .= "</div>";
    return $s;
}

sub get_basic_fields {
    my ($page_fields) = @_;
    my @basic_fields = ();
    foreach my $configfield ( @{ $page_fields } ) {
        next if ( grep { /^$configfield$/ } ( @confarrs ) );
        next if ( %dnsmconfigvals{"$configfield"}->{"mult"} ne "" );
        next if ( ( ! grep { /^$configfield$/ } ( @confbools ) ) && ( ! grep { /^$configfield$/ } ( @confsingles ) ) );
        push( @basic_fields, $configfield );
    }
    return @basic_fields;
}

=head2 show_basic_fields(\%dnsmconfig, $pageid, \@page_fields, $apply_cgi, $table_header)
=cut
sub show_basic_fields {
    my ($dnsmconfig, $pageid, $page_fields, $apply_cgi, $table_header) = @_;
    my $formid = "$pageid_basic_form";

    my @basic_fields = &get_basic_fields($page_fields);
    return if @basic_fields == 0;
    my $cbtd = 'style="width: 15px; height: 31px;"';
    my $td = 'style="height: 31px; white-space: normal !important; word-break: normal;"';
    my @tds = ( $cbtd, $td, $td );
    print &ui_form_start( $apply_cgi, "post", undef, "id='$formid'" );
    if (@basic_fields == 1) {
        my $g = &ui_columns_start( [
                "",
                $text{'column_option'},
                $text{'column_value'}
            ], undef, 0, \@tds);
        my $configfield = @basic_fields[0];
        $g .= &show_basic_fields_row($dnsmconfig, $configfield);
        $g .= &ui_columns_end();
        push(@grid, $g);
        print &ui_grid_table(\@grid, 2, 100, undef, undef, $table_header);
    }
    else {
        my $l = int(@basic_fields / 2);

        my @grid = ();
        foreach my $column_array ([ @basic_fields[0..$l-1] ], [ @basic_fields[$l..$#basic_fields] ]) {
            my $g = &ui_columns_start( [
                    "",
                    $text{'column_option'},
                    $text{'column_value'}
                ], undef, 0, \@tds);

            foreach my $configfield ( @$column_array ) {
                $g .= &show_basic_fields_row($dnsmconfig, $configfield);
            }
            $g .= &ui_columns_end();
            push(@grid, $g);
        }
        print &ui_grid_table(\@grid, 2, 100, undef, undef, $table_header);
    }

    # print &ui_form_end( [ &ui_submit( $text{"save_button"} ), &ui_reset( $text{"undo_button"} ) ] );
    print &ui_form_end( [ &ui_submit( $text{"save_button"}, "submit" ) ] );
}

sub show_basic_fields_row {
    my ($dnsmconfig, $configfield) = @_;
    my $internalfield = &config_to_internal("$configfield");

    my $cbtd = 'style="width: 15px; height: 31px;"';
    my $bigtd = 'style="height: 31px; white-space: normal !important; word-break: normal;" colspan=2';
    my $customcbtd = 'class="ui_checked_checkbox flexed" style="width: 15px; height: 31px;"';
    my $td = 'style="height: 31px; white-space: normal !important; word-break: normal;"';
    my @booltds = ( $cbtd, $bigtd );
    my @cbtds = ( $customcbtd, $td, $td );
    my @tds = ( $cbtd, $td, $td );

    my $help = &ui_help($configfield . ": " . $text{"p_man_desc_$internalfield"});
    if ( grep { /^$configfield$/ } ( @confbools ) ) {
        return &ui_checked_columns_row( [
                $text{"p_label_$internalfield"} . $help,
            ], \@booltds, "sel", $configfield, ($dnsmconfig->{$configfield}->{"used"})?1:0
        );
    }
    elsif ( grep { /^$configfield$/ } ( @confsingles ) ) {
        my $definition = %configfield_fields{$internalfield}->{"val"};
        my $tmpl = $definition->{"template"};
        my $is_used = $dnsmconfig->{$configfield}->{"used"}?1:0;
        if ( $configfield =~ /user$/ ) {
            return &ui_clickable_checked_columns_row( [
                    $text{"p_label_$internalfield"} . $help, 
                    &ui_user_textbox( $internalfield . "val", $dnsmconfig->{$configfield}->{"val"}, undef, $is_used?0:1, undef, "placeholder=\"$tmpl\" title=\"$tmpl\"" . ($definition->{"required"} == 1 ? " required" : " optional") )
                ], undef, "sel", $configfield, $is_used, undef, "onchange=\"\$('input[name=" . $internalfield . "val]').prop('disabled', (i, v) => !v);\"" );
        }
        elsif ( $configfield =~ /group$/ ) {
            return &ui_clickable_checked_columns_row( [
                    $text{"p_label_$internalfield"} . $help,
                    &ui_group_textbox( $internalfield . "val", $dnsmconfig->{$configfield}->{"val"}, undef, $is_used?0:1, undef, "placeholder=\"$tmpl\" title=\"$tmpl\"" . ($definition->{"required"} == 1 ? " required" : " optional") )
                ], undef, "sel", $configfield, $is_used, undef, "onchange=\"\$('input[name=" . $internalfield . "val]').prop('disabled', (i, v) => !v);\"" );
        }
        elsif ( $configfield =~ /(file|dir|script)$/ ) {
            return &ui_clickable_checked_columns_row( [
                    $text{"p_label_$internalfield"} . $help,
                    &ui_filebox( $internalfield . "val", $dnsmconfig->{$configfield}->{"val"}, $definition->{"length"}, $is_used?0:1, undef, "placeholder=\"$tmpl\" title=\"$tmpl\"" . ($definition->{"required"} == 1 ? " required" : " optional") )
                ], undef, "sel", $configfield, $is_used, undef, "onchange=\"\$('input[name=" . $internalfield . "val]').prop('disabled', (i, v) => !v);\"" );
        }
        else {
            return &ui_checked_columns_row( [
                    $text{"p_label_$internalfield"} . $help,
                    &ui_textbox( $internalfield . "val", %{$dnsmconfig}{$configfield}->{"val"}, $definition->{"length"}, $is_used?0:1, undef, "placeholder=\"$tmpl\" title=\"$tmpl\"" . ($definition->{"required"} == 1 ? " required" : " optional") )
                ], \@tds, "sel", $configfield, $is_used, undef, "onchange=\"\$('input[name=" . $internalfield . "val]').prop('disabled', (i, v) => !v);\""
            );
        }
    }
}

sub get_other_fields {
    my ($page_fields) = @_;
    my @var_fields = ();
    foreach my $configfield ( @{ $page_fields } ) {
        next if ( grep { /^$configfield$/ } ( @confarrs ) );
        next if ( grep { /^$configfield$/ } ( @confbools ) );
        next if ( ( grep { /^$configfield$/ } ( @confsingles ) ) && %dnsmconfigvals{"$configfield"}->{"mult"} eq "" );
        push( @var_fields, $configfield );
    }
    return @var_fields;
}

sub show_other_fields {
    my ($dnsmconfig, $pageid, $page_fields, $apply_cgi, $table_header) = @_;
    my $formid = "$pageid_other_form";

    print &ui_form_start( $apply_cgi, "post", undef, "id='$formid'" );
    my @tds = ( $td_label, $td_left );
    my @var_fields = &get_other_fields($page_fields);
    return if @var_fields == 0;
    my $col_ct = &get_max_columns(\@var_fields) + 2; # it will always have the label and radio buttons
    my @columns_arr = (3..$col_ct);
    for (@columns_arr) {
        push( @tds, $td_left );
    }
    print &ui_columns_start( undef, 100, undef, undef, &ui_columns_header( [ $table_header ], [ 'class="table-title" colspan=' . $col_ct ] ), 0 );
    foreach my $configfield ( @var_fields ) {
        my $internalfield = &config_to_internal($configfield);
        local @cols = &get_field_auto_columns($dnsmconfig, $internalfield, $col_ct);
        print &ui_columns_row( \@cols, \@tds );
    }

    print &ui_columns_end();
    print "<span color='red'>*</span>&nbsp;<i>" . $text{"footnote_required_parameter"} . "</i>";
    my @form_buttons = ();
    # push( @form_buttons, &ui_submit( $text{"cancel_button"}, "cancel" ) );
    push( @form_buttons, &ui_submit( $text{"save_button"}, "submit" ) );
    print &ui_form_end( \@form_buttons );
}

sub get_field_auto_columns {
    my ($dnsmconfig, $internalfield, $columns) = @_;
    my $configfield = &internal_to_config($internalfield);
    my $item = $dnsmconfig{"$configfield"};
    my $val;
    if (@{ %configfield_fields{$internalfield}->{"param_order"} }[0] eq "val") {
        $val = $item->{"val"};
    }
    else {
        $val = $item->{"val"};
    }
    my @cols = ();
    push ( @cols, &show_label_with_help($internalfield, $configfield) );
    # first get a list of all parameters for this field, for the radio button (ui_opt_textbox)
    # to disable the text fields for them when this value is not enabled
    my @otherfields = ();
    foreach my $key ( @{ %configfield_fields{$internalfield}->{"param_order"} } ) {
        my $definition = %configfield_fields{$internalfield}->{$key};
        push ( @otherfields, $internalfield . "_" . $key );
        # if this parameter is an array, include
        if ($definition->{"arr"} == 1) {
            push ( @otherfields, $internalfield . "_" . $key . "_additem" );
        }
    }
    # ui_opt_textbox(name, value, size, option1, [option2], [disabled?], [&extra-fields], [max], [tags])
    # ui_textbox(name, value, size, [disabled?], [maxlength], [tags])
    # ui_filebox(name, value, size, [disabled?], [maxlength], [tags], [dir-only])
    # ui_select(name, value|&values, &options, [size], [multiple], [add-if-missing], [disabled?], [javascript])
    my $count = 0;
    foreach my $key ( @{ %configfield_fields{$internalfield}->{"param_order"} }) {
        my $definition = %configfield_fields{$internalfield}->{$key};
        my $is_used = $dnsmconfig->{$configfield}->{"used"}?1:0;
        if ($count == 0) {
            push ( @cols, "<nobr>" . &ui_opt_textbox( $internalfield, $item->{"used"}?1:undef, 1, $text{"disabled"}, undef, undef, \@otherfields, undef, "dummy_field" ) . "</nobr>");
        }
        my $tmpl = $definition->{"template"};
        my $label = $definition->{"label"} || $text{"p_label_" . $internalfield . "_" . $key};
        if ($definition->{"required"}) {
            $label .= "&nbsp;<span color='red'>*</span>&nbsp;";
        }
        if ($definition->{"arr"} == 1) {
            # push ( @cols, $text{"p_label_" . $internalfield . "_" . $key} . "<br>" . &ui_select( $internalfield . "_" . $key, undef, \@{ $val->{$key} }, 3, 1 ) );
            if ($key eq "val") {
                push ( @cols, $label . "<br>" . &ui_selectbox_with_controls( $internalfield . "_" . $key, $val, 3, $definition->{"length"}, $tmpl ) );
            }
            else {
                push ( @cols, $label . "<br>" . &ui_selectbox_with_controls( $internalfield . "_" . $key, \@{ $val->{$key} }, 3, $definition->{"length"}, $tmpl ) );
            }
        }
        else {
            my $input;
            if ($definition->{"valtype"} eq "file") {
                $input = "<nobr>" . &ui_filebox( $internalfield . "_" . $key, $val->{$key}, $definition->{"length"}, undef, undef, "placeholder=\"$tmpl\" title=\"$tmpl\"" . ($definition->{"required"} == 1 ? " required" : " optional") ) . "</nobr>";
            }
            else {
                $input = &ui_textbox( $internalfield . "_" . $key, $val->{$key}, $definition->{"length"}, undef, undef, "placeholder=\"$tmpl\" title=\"$tmpl\"" . ($definition->{"required"} == 1 ? " required" : " optional") );
            }
            push ( @cols, $label . "<br>" . $input );
        }
        $count++;
    }
    while (@cols <= $columns) {
        push( @cols, "&nbsp;" );
    }
    return @cols;
}

# &show_field_table("listen_address", "dns_iface_apply.cgi", $text{"_listen"}, \%dnsmconfig);
sub show_field_table {
    my ($internalfield, $apply_cgi, $addtext, $dnsmconfig, $formidx) = @_;
    my $configfield = &internal_to_config($internalfield);
    my $definition = %configfield_fields{$internalfield};
    my $add_button;
    my $hidden_add_input_fields;
    my $hidden_edit_input_fields;
    my $edit_submit_script;
    my @newfields = @{$definition->{"param_order"}};
    my @editfields = ( "idx", @newfields );
    my $formid = $internalfield . "_form";
    my @tds = ( $td_label, $td_left );
    my @pathtypes = ( "file", "path", "dir" );
    my @column_headers = ( 
        "",
        $text{"enabled"}
    );
    if ( @newfields == 1 ) {
        push(@column_headers, $definition->{"@newfields[0]"}->{"label"} );
        push( @tds, $td_left );
    }
    else {
        foreach my $param ( @newfields ) {
            push(@column_headers, $definition->{"$param"}->{"label"} );
            push( @tds, $td_left );
        }
    }
    my @list_link_buttons = &list_links( "sel", $formidx );
    if ($definition->{"val"} && $definition->{"val"}->{"valtype"} eq "interface") {
        ($add_button, $hidden_add_input_fields) = &add_interface_chooser_button( &text("add_", $text{"_iface"}), "new_" . $internalfield, $formid );
    }
    else {
        ($add_button, $hidden_add_input_fields) = &add_item_button(&text("add_", $addtext), $internalfield, $text{"p_label_$internalfield"}, $formid, \@newfields );
        push(@list_link_buttons, $add_button);
    }

    my $count=0;
    print &ui_form_start( $apply_cgi, "post", undef, "id='$formid'" );
    print &ui_links_row(\@list_link_buttons);
    if ($definition->{"val"} && $definition->{"val"}->{"valtype"} eq "interface") {
        print $hidden_add_input_fields . $add_button;
    }
    print &ui_columns_start( \@column_headers, 100, undef, undef, 
        &ui_columns_header( [ &show_title_with_help($internalfield, $configfield) ], 
        [ 'class="table-title" colspan=' . @column_headers ] ), 1 );
    foreach my $item ( @{$dnsmconfig{$configfield}} ) {
        local @cols;
        push ( @cols, &ui_checkbox("enabled", "1", "", $item->{"used"}?1:0, undef, 1) );
        foreach my $param ( @newfields ) {
            my $edit_link;
            my $valtype = $definition->{"$param"}->{"valtype"};
            my $val = ($param eq "val") ? $item->{"$param"} : $item->{"val"}->{"$param"};
            if ($definition->{"$param"}->{"arr"} == 1 && ref($val) eq "ARRAY") {
                $val = join($definition->{"$param"}->{"sep"}, @{$val})
            }
            elsif ($valtype eq "bool") {
                $val = &ui_checkbox("boolval", "1", "", $val, undef, 1)
            }
            if ($count == 0) {
                if ($valtype eq "interface") {
                    # edit_interface_chooser_link(text, input, current_value, idx, formid, [addmode])
                    ($edit_link, $hidden_edit_input_fields, $edit_submit_script) = &edit_interface_chooser_link($val, $internalfield, $val, $count, $formid);
                }
                elsif (grep { /^$valtype$/ } ( @pathtypes )) {
                    ($edit_link, $hidden_edit_input_fields, $edit_submit_script) = &edit_file_chooser_link($val, $internalfield, ($valtype eq "file" ? 0 : 1), $val, $count, $formid);
                }
                else {
                    # first call to &edit_item_link should capture link and fields; subsequent calls (1 for each field) only need the link
                    ($edit_link, $hidden_edit_input_fields) = &edit_item_link($val, $internalfield, $text{"p_desc_$internalfield"}, $count, $formid, \@editfields);
                }
            }
            else {
                if ($valtype eq "interface") {
                    ($edit_link) = &edit_interface_chooser_link($val, $internalfield, $val, $count, $formid);
                }
                elsif (grep { /^$valtype$/ } ( @pathtypes )) {
                    ($edit_link) = &edit_file_chooser_link($val, $internalfield, ($valtype eq "file" ? 0 : 1), $val, $count, $formid);
                }
                else {
                    ($edit_link) = &edit_item_link($val, $internalfield, $text{"p_desc_$internalfield"}, $count, $formid, \@editfields);
                }
            }
            push ( @cols, $edit_link );
        }
        print &ui_clickable_checked_columns_row( \@cols, \@tds, "sel", $count );
        $count++;
    }
    print &ui_columns_end();
    print &ui_links_row(\@list_link_buttons);
    if ($definition->{"val"} && $definition->{"val"}->{"valtype"} eq "interface") {
        print $hidden_add_input_fields . $add_button;
    }
    print "<p>" . $text{"with_selected"} . "</p>";
    print &ui_submit($text{"enable_sel"}, "enable_sel_$internalfield");
    print &ui_submit($text{"disable_sel"}, "disable_sel_$internalfield");
    print &ui_submit($text{"delete_sel"}, "delete_sel_$internalfield");
    if (!$definition->{"val"} || $definition->{"val"}->{"valtype"} ne "interface") {
        print $hidden_add_input_fields;
    }
    print $hidden_edit_input_fields;
    print $edit_submit_script;
    print &ui_form_end();
    print &ui_hr();
}

sub show_path_list {
    my ($internalfield, $apply_cgi, $add_button_text, $val_label, $chooser_mode, $formidx) = @_;
    my $configfield = &internal_to_config($internalfield);
    my $count=0;
    my $edit_link;
    my $hidden_edit_input_fields;
    my $edit_submit_script;
    my $formid = $internalfield . "_form";
    print &ui_form_start( $apply_cgi . "?mode=$internalfield", "post", undef, "id='$formid'" );
    my @list_link_buttons = &list_links( "sel", $formidx );
    my ($file_chooser_button, $hidden_add_input_fields) = &add_file_chooser_button( &text("add_", $add_button_text), "new_" . $internalfield, $chooser_mode, $formid );
    print &ui_links_row(\@list_link_buttons);
    print $hidden_add_input_fields;
    print $file_chooser_button;
    print &ui_columns_start( [ 
        "",
        $text{"enabled"}, 
        $val_label, 
        # "full" 
    ], 100, undef, undef, &ui_columns_header( [ &show_title_with_help($internalfield, $configfield) ], [ 'class="table-title" colspan=3' ] ), 1 );

    foreach my $item ( @{$dnsmconfig{$configfield}} ) {
        local @cols;
        push ( @cols, &ui_checkbox("enabled", "1", "", $item->{"used"}?1:0, undef, 1) );
        # edit_file_chooser_link(text, input, type, current_value, idx, formid, [chroot], [addmode])
        ($edit_link, $hidden_edit_input_fields, $edit_submit_script) = &edit_file_chooser_link($item->{"val"}, $internalfield, $chooser_mode, $item->{"val"}, $count, $formid);
        push ( @cols, $edit_link );
        print &ui_clickable_checked_columns_row( \@cols, \@tds, "sel", $count );
        $count++;
    }
    print &ui_columns_end();
    print &ui_links_row(\@list_link_buttons);
    print $hidden_add_input_fields;
    print $file_chooser_button;
    print "<p>" . $text{"with_selected"} . "</p>";
    print &ui_submit($text{"enable_sel"}, "enable_sel_$internalfield");
    print &ui_submit($text{"disable_sel"}, "disable_sel_$internalfield");
    print &ui_submit($text{"delete_sel"}, "delete_sel_$internalfield");
    print $hidden_edit_input_fields;
    print $edit_submit_script;
    print &ui_form_end( );
    print $g;
}

sub do_selected_action {
    my ($internalfields, $sel, $dnsmconfig) = @_;

    foreach my $internalfield ( @{$internalfields}) {
        my $configfield = &internal_to_config($internalfield);
        my $action = $in{"enable_sel_$internalfield"} ? "enable" : $in{"disable_sel_$internalfield"} ? "disable" : $in{"delete_sel_$internalfield"} ? "delete" : "";
        if ($action ne "") {
            @{$sel} || &error($text{'selected_none'});

            &update_selected($configfield, $action, $sel, $dnsmconfig);
            last;
        }
    }
}

=head2 ui_clickable_checked_columns_row($columns, $tdtags, checkname, checkvalue, [checked?], [disabled], [tags])
=cut
sub ui_clickable_checked_columns_row {
    my ($columns, $tdtags, $checkname, $checkvalue, $checked, $disabled, $tags) = @_;

    $checkname = $checkname || "sel";

    my $customcbtd = "class=\"ui_checked_checkbox flexed clickable_tr" . ($checked ? " clickable_tr_selected" : "") . "\" style=\"width: 15px; height: 29px;\"";
    my $td = 'class="cursor-pointer" style="height: 29px; white-space: normal !important; word-break: normal;"';
    my @cbtds = ( $customcbtd );

    my @cols = (
        # ui_checkbox(name, value, label, selected?, [tags], [disabled?])
        '<div class="wh-100p flex-wrapper flex-centered flex-start">' . &ui_checkbox($checkname, $checkvalue, undef, ($checked)?1:0, $tags, $disabled, ' thick' ) . '</div>',
        @{ $columns }
    );
    if ($tdtags) {
        @cbtds = ( $customcbtd, @{ $tdtags } );
    }
    else {
        foreach my $col (@{ $columns }) {
            push ( @cbtds, $td );
        }
    }

    # return &ui_columns_row( \@cols, ($tdtags ? $tdtags : \@cbtds) );
    return &ui_columns_row( \@cols, \@cbtds );
}

sub show_title_with_help {
    my ($internalfield, $configfield) = @_;
    return $text{"p_desc_$internalfield"} . &ui_help($configfield . ": " . $text{"p_man_desc_$internalfield"})
}

sub show_label_with_help {
    my ($internalfield, $configfield) = @_;
    return $text{"p_label_$internalfield"} . &ui_help($configfield . ": " . $text{"p_man_desc_$internalfield"})
}

sub get_max_columns {
    my ($configfields) = @_;
    my $current_max = 0;
    foreach my $configfield ( @{ $configfields } ) {
        my $internalfield = &config_to_internal($configfield);
        if ($current_max <= @{ %configfield_fields{$internalfield}->{"param_order"} }) {
            $current_max = @{ %configfield_fields{$internalfield}->{"param_order"} };
        }
    }
    return $current_max;
}

sub string_contains {
    return (index($_[0], $_[1]) != -1);
}

sub custom_theme_ui_links_row {

    my ($links, $nopuncs) = @_;
    my $link = "<a";
    if (ref($links)) {
        if (string_contains("@$links", $link)) {
            @$links =
              map {string_contains($_, $link) ? $_ : "<span class=\"btn btn-success ui_link ui_link_empty\">$_</span>"}
              @$links;
            return @$links ? "<div class=\"btn-group ui_links_row\" role=\"group\">" . join("", @$links) . "</div>\n" :
              "";
        } else {
            if ($nopuncs == 1) {
                return @$links ? join(", ", @$links) . "\n" : "";
            } elsif ($nopuncs == 2) {
                return @$links ? join(" ", @$links) . "\n" : "";
            } else {
                my $dot = ".";
                if (scalar(@$links) == 1) {
                    $dot = "";
                }
                return @$links ? join(", ", @$links) . "$dot\n" : "";
            }
        }
    }
}

sub check_for_file_errors {
if( $dnsmconfig{"errors"} > 0 ) {
    my $line = "error.cgi?line=xx&type=" . &urlize($text{"err_configbad"});
    &redirect( $line );
    exit;
}
}

sub header_js {
    my ($formid, $internalfield) = @_;
    my $script = "";
    $script .= "<script type='text/javascript'>\n"
             . "function addItemToSelect(sel){\n"
             . "    let v=\$(\"input[name=\"+sel+\"_additem]\").val();\n"
             . "    if (v) \$(\"select[name=\"+sel+\"]\").append(\$(\"<option></option>\").attr(\"value\",v).text(v));\n"
             . "    \$(\"input[name=\"+sel+\"_additem]\").val(\"\");\n"
             . "}\n"
             . "function removeSelectItem(sel){\n"
             . "    var sItems=[];\n"
             . "    \$(\"select[name=\"+sel+\"]\").each(function(){\n"
             . "        sItems.push(\$(this).val());\n"
             . "    });\n"
             . "    \$(\"select[name=\"+sel+\"]\").each(function(i,select){\n"
             . "        \$(\"select[name=\"+sel+\"] option\").each(function(ii,option){\n"
             . "            if(\$(option).val() != \"\" && sItems[i] == \$(option).val() && sItems[i] != \$(option).parent().val()){\n"
             . "                \$(option).remove();\n"
             . "            }\n"
             . "        });\n"
             . "    });\n"
             . "}\n"
             . "</script>\n";
    return $script;
}

sub header_style {
    my $style = "<style type='text/css'>\n"
            . ".select_invert {\n"
            . "  margin-right: unset !important;\n"
            . "}\n"
            . ".new-dnsm-button-container {\n"
            . "  margin-top: -1px;\n"
            . "  position: absolute;\n"
            . "}\n"
            . ".add-item-button-small {\n"
            . "  height: 28px !important;\n"
            . "  margin-left: -4px;\n"
            . "  display: inline-block;\n"
            . "}\n"
            . ".remove-item-button-small {\n"
            . "  height: 28px !important;\n"
            . "  margin-right: 4px;\n"
            . "  display: inline-block;\n"
            . "}\n"
            . "select[multiple] {\n"
            . "  min-height: unset !important;\n"
            . "  max-height: unset !important;\n"
            . "}\n"
            . "html[data-bgs='nightRider'] .hl-aw, .hl-aw {\n"
            . "  background-color: unset !important;\n"
            . "}\n"
            . "\n"
            . "</style>\n";
    return $style;
}
=head2 add_js()
=cut
sub add_js {
    my $script = "";
    $script .= "<script type='text/javascript'>\n"
             . "\$(document).ready(function() {\n"
             . "  setTimeout(function() {\n"
             . "    \$(\"<i class='fa fa-minus-square -cs vertical-align-middle' style='margin-right: 8px;'></i>\").prependTo(\".select-none\");\n" # adds icon to "select none" link/button
             . "    \$(\"<i class='fa fa-fw fa-files-o -cs vertical-align-middle' style='margin-right:5px;'></i>\").prependTo(\".file-chooser-button\");\n" # adds icon to "new file" link/button
             . "    \$(\".new-file-input, .new-iface-input\").each(function(){\$(this).parent().appendTo(\$(this).parent().prevUntil(\".btn-group\").last().prev());\$(this).parent().prev().css(\"margin-right\", \"0px !important\");\$(this).parent().addClass(\"new-dnsm-button-container\");});\n" # adds "new file/interface" link to button list
             . "    \$(\".new-file-input, .new-iface-input\").each(function(){replaceWithWrapper(\$(this), \"value\", function(obj){\$(obj).closest(\"form\").trigger(\"submit\");});});\n" # submits "new file/interface" button's form when one is selected
             . "    \$(\"<i class='fa fa2 fa2-plus-network vertical-align-middle' style='margin-right:5px;'></i>\").prependTo(\".iface-chooser-button\");\n" # adds icon to "new interface" link/button
             . "    \$(\"<i class='fa fa-plus vertical-align-middle' style='margin-right: 8px; margin: 5px 8px 5px 0px;'></i>\").prependTo(\".add-item-button\");\n" # adds icon to "new <item>" link/button
             . "    \$(\"<i class='fa fa-trash vertical-align-middle' style='margin-right: 8px;'></i>\").prependTo(\".remove-item-button\");\n" # adds icon to "remove <item>" link/button
             . "    \$(\"<i class='fa fa-plus vertical-align-middle' style='margin: 4px;'></i>\").prependTo(\".add-item-button-small\");\n" # adds icon to mini "new <item>" button for select box
             . "    \$(\"<i class='fa fa-trash vertical-align-middle' style='margin: 4px;'></i>\").prependTo(\".remove-item-button-small\");\n" # adds icon to mini "remove <item>" button for select box
             . "    \$(\".clickable_tr\").each(function(){\$(this).parent().addClass(\"ui_checked_columns\");});\n" # fixes styling for clickable table row checkboxes
             . "    \$(\".clickable_tr_selected\").each(function(){\$(this).removeClass(\"clickable_tr_selected\");\$(this).parent().addClass(\"hl-aw\");});\n" # fixes styling for clickable table row checkboxes
             . "    \$(\"input[dummy_field]\").hide();"
             . "  }, 0);\n";
    $script .= "  if (!\$('#list-item-edit-modal').length) {\n"
             . "    var g='<div class=\"modal fade fade5 in\" id=\"list-item-edit-modal\" tabindex=\"-1\" role=\"dialog\" aria-hidden=\"true\">"
             . "      <div class=\"modal-dialog\">"
             . "        <div class=\"modal-content\" style=\"padding: 10px;\">"
            #  . "          <div class=\"modal-header \"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-label=\"Close\"><span aria-hidden=\"true\">×</span></button><h4 class=\"modal-title\"></h4></div>"
             . "        </div>"
             . "      </div>"
             . "    </div>';\n"
             . "    \$(document.body).append(g);\n"
             . "    \$(\"#list-item-edit-modal\").on('hidden.bs.modal', function () {\n"
             . "      \$(this).data('bs.modal', null);\n"
             . "      \$(this).find(\".modal-content\").html(\"\");\n"
             . "    });\n"
             . "  }\n"
             . "\n"
             . "});\n";
    $script .= "function addItemToSelect(sel){\n"
             . "    let v=\$(\"input[name=\"+sel+\"_additem]\").val();\n"
             . "    if (v) \$(\"select[name=\"+sel+\"]\").append(\$(\"<option></option>\").attr(\"value\",v).text(v));\n"
             . "    \$(\"input[name=\"+sel+\"_additem]\").val(\"\");\n"
             . "}\n"
             . "function removeSelectItem(sel){\n"
             . "    var sItems=[];\n"
             . "    \$(\"select[name=\"+sel+\"]\").each(function(){\n"
             . "        sItems.push(\$(this).val());\n"
             . "    });\n"
             . "    \$(\"select[name=\"+sel+\"]\").each(function(i,select){\n"
             . "        \$(\"select[name=\"+sel+\"] option\").each(function(ii,option){\n"
             . "            if(\$(option).val() != \"\" && sItems[i] == \$(option).val() && sItems[i] != \$(option).parent().val()){\n"
             . "                \$(option).remove();\n"
             . "            }\n"
             . "        });\n"
             . "    });\n"
             . "}\n";
    $script .= "function submit_form(vals, formid) {"
             . "  vals.forEach((o) => {"
             . "    let f=o.f;let v=o.v;"
             . "    if (f==\"submit\") return;"
             . "    var selector = \"#\" + formid + \" input[name=\"+f+\"]\";"
             . "    \$( selector ).val(v);"
             . "  });"
             . "  \$(\"#\"+formid).submit();"
             . "}\n";
    $script .= "function replaceWithWrapper(selector, property, callback) {\n"
             . "    function findDescriptor(obj, prop){\n"
             . "        if (obj != null){\n"
             . "            return Object.hasOwnProperty.call(obj, prop)?\n"
             . "                Object.getOwnPropertyDescriptor(obj, prop):\n"
             . "                findDescriptor(Object.getPrototypeOf(obj), prop);\n"
             . "        }\n"
             . "    }\n"
             . "\n"
             . "    jQuery(selector).each(function(idx, obj) {\n"
             . "        var {get, set} = findDescriptor(obj, property);\n"
             . "\n"
             . "        Object.defineProperty(obj, property, {\n"
             . "            configurable: true,\n"
             . "            enumerable: true,\n"
             . "\n"
             . "            get() { //overwrite getter\n"
             . "                var v = get.call(this);  //call the original getter\n"
             . "                //console.log(\"get '+property+':\", v, this);\n"
             . "                return v;\n"
             . "            },\n"
             . "\n"
             . "            set(v) { //same for setter\n"
             . "                //console.log(\"set '+property+':\", v, this);\n"
             . "                set.call(this, v);\n"
             . "                callback(obj, property, v)\n"
             . "            }"
             . "        });\n"
             . "    });\n"
             . "}\n";
    #          . "</div>\n";
    $script .= "</script>\n";
    return $script;
}

1;
