#
#   Proc::PID::File - pidfile manager
#   Copyright (C) 2001-2003 Erick Calder
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

package Proc::PID::File;

=head1 NAME

Proc::PID::File - a module to manage process id files

=head1 SYNOPSIS

  use Proc::PID::File;
  die "Already running!" if Proc::PID::File->running();

=head1 DESCRIPTION

This Perl module is useful for writers of daemons and other processes that need to tell whether they are already running, in order to prevent multiple process instances.  The module accomplishes this via *nix-style I<pidfiles>, which are files that store a process identifier.

The module provides three interfaces: 1) a simple call, 2) an object-oriented interface, and 3) a regular procedural function set.

=cut

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(hold_pid_file release_the_pid_file);
@EXPORT_OK = qw(
	pid_file_set pid_file_read pid_file_write pid_file_alive pid_file_remove
	);
use Fcntl qw(:DEFAULT :flock);

use strict;
use vars qw($VERSION $RPM_Requires);

$VERSION = "1.23";
$RPM_Requires = "procps";

my $RUNDIR = "/var/run";
my $ME = $0; $ME =~ s|.*/||;

# -- Simple Interface --------------------------------------------------------

=head1 Simple Interface

The simple interface consists of a call as indicated in the B<Synopsis> section above.  This approach avoids causing race conditions whereby one instance of a daemon could read the I<pidfile> after a previous instance has read it but before it has had a chance to write to it.

=head2 running [hash[-ref]]

The parameter signature for this function is identical to that of the I<-E<gt>file()> method described below with the exception of the additional parameter listed below.  The mothod's return value is the same as that of I<-E<gt>alive()>.

=over

=item I<verify> = 1 | string

This parameter helps prevent the problem described in the WARNING section below.  If set to a string, it will be interpreted as a I<regular expression> and used to search within the name of the running process.  A 1 may also be passed, indicating that the value of I<$0> should be used (stripped of its full path).  If the parameter is not passed, no verification will take place.

Please note that verification will only work for the operating systems listed below and that the os will be auto-sensed.  See also DEPENDENCIES section below.

Supported platforms: Linux, FreeBSD

=back

=cut

sub running {
    my $self = shift->new(@_);
	my $path = $self->{path};

    local *FH;
	sysopen(FH, $path, O_RDWR|O_CREAT)
		|| die qq/Cannot open pid file "$path": $!\n/;
	flock(FH, LOCK_EX | LOCK_NB)
        || die "pid " . $self->{'path'} . " already locked";
	my ($pid) = <FH> =~ /^(\d+)/;

	if ($pid && $pid != $$ && kill(0, $pid)) {
        $self->debug("running: $pid");
        if ($self->verify($pid)) {
	        close FH;
	        return $pid;
            }
        }

    $self->debug("writing: $$");
	sysseek  FH, 0, 0;
	truncate FH, 0;
	syswrite FH, "$$\n", length("$$\n");
	close(FH) || die qq/Cannot write pid file "$path": $!\n/;

	return 0;
    }

sub verify {
    my ($self, $pid) = @_;
    return 1 unless $self->{verify};

    eval "use Config";
    die "$@\nCannot use the Config module.  Please install.\n" if $@;

    $self->debug("verifying on: $Config::Config{osname}");
    if ($Config::Config{osname} =~ /linux|freebsd/i) {
        my $me = $self->{verify};
        ($me = $0) =~ s|.*/|| if !$me || $me eq "1";
        my @ps = split m|$/|, qx/ps -fp $pid/
            || die "ps utility not available: $!";
        s/^\s+// for @ps;   # leading spaces confuse us

        no warnings;    # hate that deprecated @_ thing
        my $n = split(/\s+/, $ps[0]);
        @ps = split /\s+/, $ps[1], $n;
        return scalar grep /$me/, $ps[$n - 1];
        }
    }

# -- Object oriented Interface -----------------------------------------------

=head1 OO Interface

The following methods are provided:

=head2 new [hash[-ref]]

This method is used to create an instance of the module.  It automatically calls the I<-E<gt>file()> method described below and receives the same paramters.  For a listing of valid keys in this has please refer to the aforementioned method documentation below.

In addition to the above, the following constitute valid keys:

=over

=item I<debug>

Turns debugging output on.

=back

=cut

sub new {
	my $class = shift;
	my $self = bless({}, $class);
	%$self = &args;

	$self->file();		# init file path

	return $self;
	}

=head2 file [hash[-ref]]

Use this method to set the path of the I<pidfile>.  The method receives an optional hash (or alternatively a hash reference) of options, which includes those listed below, from which it makes a path of the format: F<$dir/$name.pid>.

=over

=item I<dir>

Specifies the directory to place the pid file.  If left unspecified, defaults to F</var/run>.

=item I<name>

Indicates the name of the current process.  When not specified, defaults to I<basename($0)>.

=back

=cut

sub file {
	my $self = shift;
	%$self = (%$self, &args);
	$self->{dir} ||= $RUNDIR;
	$self->{name} ||= $ME;
	$self->{path} = sprintf("%s/%s.pid", $self->{dir}, $self->{name});
	}

=head2 alive

Returns true when the calling process is already running.  Please note that this call must be made *after* daemonisation i.e. subsequent to the call to fork().

=cut

sub alive {
	my $self = shift;
	my $pid = $self->read() || "";

	$self->debug("alive($pid)");
	return $pid if $pid && $pid != $$ && kill(0, $pid);

	$self->write();
	return 0;
	}

=head2 read

Returns the process id currently stored in the file set.  If unable to open the file for read, the method die()s with an error message.

=cut

sub read {
	my $self = shift;

	$self->debug("read()");
	local *FH;
	sysopen FH, $self->{path}, O_RDWR|O_CREAT
		|| die qq/Cannot open pid file "$self->{path}": $!\n/;
	flock(FH, LOCK_EX | LOCK_NB)
        || die "pid " . $self->{'path'} . " already locked";
	my ($pid) = <FH> =~ /^(\d+)/;
	close FH;

	return $pid;
	}

=head2 write

Causes for the current process id to be written to the set file.  The process die()s upon failure to write to the file.

=cut

sub write {
	my $self = shift;

	$self->debug("write($$)");
	local *FH;
	sysopen FH, $self->{path}, O_RDWR|O_CREAT
		|| die qq/Cannot open pid file "$self->{path}": $!\n/;
	flock(FH, LOCK_EX | LOCK_NB)
        || die "pid " . $self->{'path'} . " already locked";
	sysseek  FH, 0, 0;
	truncate FH, 0;
	syswrite FH, "$$\n", length("$$\n");
	close FH || die qq/Cannot write pid file "$self->{path}": $!\n/;
	}

=head2 remove

This method is used to delete the I<pidfile> and is automatically called by DESTROY method.  It should thus be unnecessary to call it directly.

=cut

sub remove {
	my $self = shift;
	$self->debug("remove()");
	unlink($self->{path}) || warn $!;
	}

sub args {
	my $opts = shift;
	!defined($opts) ? () : ref($opts) ? %$opts : ($opts, @_);
	}

# -- Procedural Interface ----------------------------------------------------

=head1 Procedural interface

The module can also export its functionality into the caller's namespace.  The functions exported generally correspond to those in the OO interface but follow the naming format: C<pid_file_E<lt>nameE<gt>>.

As an exception, instead of calling I<-E<gt>new()> the user will need to call I<pid_file_set> before making any other calls.

- I<exempli gratia> -

  use Proc::PID::File qw(:all);
  pid_file_set( dir => "/var/run", name => "mydaemon" );
  die "Already running!" if pid_file_alive();

=cut

my $self;

sub pid_file_set {
	$self = Proc::PID::File->new();
	$self->file(@_);
	}

sub pid_file_read {
	die "No file set!" unless $self;
	$self->read();
	}

sub pid_file_write {
	die "No file set!" unless $self;
	$self->write();
	}
	
sub pid_file_alive {
	die "No file set!" unless $self;
	$self->alive();
	}
	
sub pid_file_remove {
	die "No file set!" unless $self;
	$self->remove();
	}

# -- support functionality ---------------------------------------------------

sub debug {
	my $self = shift;
	my $msg = shift || $_;

	print "> Proc::PID::File - $msg"
		if $self->{debug};
	}

sub DESTROY {
	my $self = shift;

    my $pid = $self->read();
    $self->remove() if $self->{path} && $pid && $pid == $$;
	}

1;

__END__

# -- documentation -----------------------------------------------------------

=head1 AUTHOR

Erick Calder <ecalder@cpan.org>

=head1 ACKNOWLEDGEMENTS

1k thx to Steven Haryanto <steven@haryan.to> whose package (Proc::RID_File) inspired this implementation.

Our gratitude also to Alan Ferrency <alan@pair.com> for fingering the boot-up problem and suggesting possible solutions.

=head1 DEPENDENCIES

For Linux and FreeBSD, support of the I<verify> option (simple interface) requires the B<ps> utility to be available.  This is typically found in the B<procps> RPM.

=head1 WARNING

This module may prevent daemons from starting at system boot time.  The problem occurs because the process id written to the I<pidfile> by an instance of the daemon may coincidentally be reused by another process after a system restart, thus making the daemon think it's already running.

Some ideas on how to fix this problem are catalogued below, but unfortunately, no platform-independent solutions have yet been gleaned.

=over

=item - leaving the I<pidfile> open for the duration of the daemon's life

=item - checking a C<ps> to make sure the pid is what one expects (current implementation)

=item - looking at /proc/$PID/stat for a process name

=item - check mtime of the pidfile versus uptime; don't trust old pidfiles

=item - try to get the script to nuke its pidfile when it exits (this is vulnerable to hardware resets and hard reboots)

=item - try to nuke the pidfile at boot time before the script runs; this solution suffers from a race condition wherein two instances read the I<pidfile> before one manages to lock it, thus allowing two instances to run simultaneously.

=back

=head1 RFC

The following is a request-for-comments on the following issues:

1) Would welcome feedback on whether I should just drop the OO and procedural interfaces and leave only the simple interface.

2) A better solution to boot-up problem described above would be most welcome.

=head1 SUPPORT

For help and thank you notes, e-mail the author directly.  To report a bug, submit a patch or add to our wishlist please visit the CPAN bug manager at: F<http://rt.cpan.org>

=head1 AVAILABILITY

The latest version of the tarball, RPM and SRPM may always be found at: F<http://perl.arix.com/>  Additionally the module is available from CPAN.

=head1 LICENCE

This utility is free and distributed under GPL, the Gnu Public License.  A copy of this license was included in a file called LICENSE. If for some reason, this file was not included, please see F<http://www.gnu.org/licenses/> to obtain a copy of this license.

$Id: File.pm,v 1.15 2003/11/02 01:36:07 ekkis Exp $
