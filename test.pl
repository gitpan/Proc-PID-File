#!/usr/bin/perl

#
#   Proc::PID::File - test suite
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

use strict;
use warnings;

#   make sure this script can find the module
#   without being run by 'make test' (see --deamon switch below).
use lib "blib/lib";

#   set up expectations

$|++; $\ = "\n";
use Test::Simple tests => 13;

use Proc::PID::File;
ok(1, 'use Proc::PID::File'); # If we made it this far, we're ok.

my $pf = Proc::PID::File->new(
	dir => ".",
	name => "test",
	debug => $ENV{DEBUG}
	);

my $cmd = shift || "";
exit() if $cmd eq "--short";

$pf->write(), sleep(5), exit()
	if $cmd eq "--daemon";

#
# --- test simple interface -----------------------------------------------
#

my %args = ( name => "test", dir => ".", debug => $ENV{DEBUG} );

unlink("test.pid") || die $! if -e "test.pid";  # blank slate
system qq|$^X $0 --daemon > /dev/null 2>&1 &|; sleep 1;
my $pid = qx/cat test.pid/; chomp $pid;

my $rc = Proc::PID::File->running(%args);
ok($rc, "* simple interface");

$rc = Proc::PID::File->running(%args, verify => 1);
ok($rc, "verified: real");

# WARNING: the following test takes over the pidfile from the
# daemon such that he cannot clean it up.  this is as it should be
# since no one but us should occupy our pidfile 

$rc = Proc::PID::File->running(%args, verify => "falsetest");
ok(! $rc, "verified: false");

sleep 1 while kill 0, $pid;

$rc = Proc::PID::File->running(%args);
ok(! $rc, "single instance");

#
# --- test OO interface ---------------------------------------------------
#

# test no one running

ok(1, "* OO interface");
ok(! $pf->alive(), "single instance");
ok($pf->read() == $$, "id read");
$pf->remove();
ok(! -f $pf->{path}, "pidfile removed");
exit(1) if -f $pf->{path};

# test someone running

system qq|$^X $0 --daemon > /dev/null 2>&1 &|;
wait until -f $pf->{path};
ok(1, "write tested");
ok($pf->alive(), "second incarnation");

# test DESTROY

system qq|$^X $0 --short > /dev/null 2>&1|;
ok(-f $pf->{path}, "destroy");

ok(1, "done");
