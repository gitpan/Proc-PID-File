package Proc::PID::File;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(hold_pid_file release_the_pid_file);
@EXPORT_OK = qw(
	pid_file_set pid_file_read pid_file_write pid_file_alive pid_file_remove
	);
use Fcntl qw(:DEFAULT :flock);

use strict;
use vars qw($VERSION);

$VERSION = (qw($Revision: 1.3 $))[1];

my $RUNDIR = "/var/run";
my $ME = $0; $ME =~ s|.*/||;

# -- Object oriented Interface -----------------------------------------------

sub new {
	my $class = shift;
	my $self = bless({}, $class);
	%$self = &args;

	$self->file();		# init file path

	return $self;
	}

sub file {
	my $self = shift;
	%$self = (%$self, &args);
	$self->{dir} ||= $RUNDIR;
	$self->{name} ||= $ME;
	$self->{path} = sprintf("%s/%s.pid", $self->{dir}, $self->{name});
	}

sub read {
	my $self = shift;

	local *FH;
	sysopen FH, $self->{path}, O_RDWR|O_CREAT
		|| die qq/Cannot open pid file "$self->{path}": $!\n/;
	flock FH, LOCK_EX;
	my ($pid) = <FH> =~ /^(\d+)/;
	close FH;

	return $pid;
	}

sub write {
	my $self = shift;

	local *FH;
	sysopen FH, $self->{path}, O_RDWR|O_CREAT
		|| die qq/Cannot open pid file "$self->{path}": $!\n/;
	flock FH, LOCK_EX;
	sysseek  FH, 0, 0;
	truncate FH, 0;
	syswrite FH, "$$\n", length("$$\n");
	close FH || die qq/Cannot write pid file "$self->{path}": $!\n/;
	}

sub alive {
	my $self = shift;
	my $pid = $self->read();

	print "> Proc::PID::File - pid: $pid"
		if $self->{debug};
	return $pid if $pid && $pid != $$ && kill(0, $pid);

	$self->write();
	return 0;
	}

sub remove {
	my $self = shift;
	unlink($self->{path}) || warn $!;
	}

sub args {
	my $opts = shift;
	!defined($opts) ? () : ref($opts) ? %$opts : ($opts, @_);
	}

# -- Procedural Interface ----------------------------------------------------

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

sub DESTROY {
	my $self = shift;
	my $pid = $self->read();
	$self->remove() if $self->{path} && $pid && $pid == $$;
	}

1;

__END__

# -- documentation -----------------------------------------------------------

=head1 NAME

Proc::PID::File - a module to manage process id files

=head1 SYNOPSIS

  use Proc::PID::File;
  $pf = Proc::PID::File->new();
  die "Already running!" if $pf->alive();

=head1 DESCRIPTION

This Perl module is useful for writers of daemons and other processes that need to tell whether they are already running.  The module manages *nix-style I<pidfiles>, which are files that store a process identifier, and provides a simple interface for determining whether the program being run is already alive.  A programmer can thus avoid running multiple instances of a daemon.

The module provides both an object-oriented interface, as well as a regular procedural function set.

=head1 OO Interface

The following methods are provided:

=head2 new [hash[-ref]]

This method is used to create an instance of the module.  It automatically calls the I<-E<gt>file()> method described below and receives the same paramters.  For a listing of valid keys in this has please refer to the aforementioned method documentation below.

In addition to the above, the following constitute valid keys:

=item debug

Turns debugging output on.

=head2 file [hash[-ref]]

Use this method to set the path of the I<pidfile>.  The method receives an optional hash (or alternatively a hash reference) of options, which includes those listed below, from which it makes a path of the format: F<$dir/$name.pid>.

=item dir
Specifies the directory to place the pid file.  If left unspecified, defaults to F</var/run>.

=item name
Indicates the name of the current process.  When not specified, defaults to I<basename($0)>.

=head2 alive

Returns true when the calling process is already running.  Please note that this call must be made *after* daemonisation i.e. subsequent to the call to fork().

=head2 read

Returns the process id currently stored in the file set.  If unable to open the file for read, the method die()s with an error message.

=head2 write

Causes for the current process id to be written to the set file.  The process die()s upon failure to write to the file.

=head2 remove

This method is used to delete the I<pidfile> and is automatically called by DESTROY method.  It should thus be unnecessary to call it directly.

=head1 Procedural interface

The module can also export its functionality into the caller's namespace.  The functions exported generally correspond to those in the OO interface but follow the naming format: C<pid_file_E<lt>nameE<gt>>.

As an exception, instead of calling I<-E<gt>new()> the user will need to call I<pid_file_set> before making any other calls.

- I<exempli gratia> -

  use Proc::PID::File qw(:all);
  pid_file_set( dir => "/var/run", name => "mydaemon" );
  die "Already running!" if pid_file_alive();
	
=head1 AUTHOR

Erick Calder <ecalder@cpan.org>

=head1 ACKNOWLEDGEMENTS

1k thx to Steven Haryanto <steven@haryan.to> on whose original package (Proc::RID_File) this work is based.

=head1 LICENSE

Copyright (C) 2000-2002, All rights reserved.

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 CHANGES

$Log: File.pm,v $
Revision 1.2  2002/09/20 06:38:45  ekkis
- ripped out the procedure interface, concentrating on oo
- added modified PODs

