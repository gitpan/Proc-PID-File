#!/usr/bin/perl

#   make sure this script can find the module
#   without being run by 'make test' (see --deamon switch below).

use strict;
use warnings;
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

unlink("test.pid") || die $! if -e "test.pid";  # blank slate
system qq|./test.pl --daemon > /dev/null 2>&1 &|; sleep 1;
my $pid = qx/cat test.pid/; chomp $pid;

my $rc = Proc::PID::File->running(
    name => "test", dir => "."
    );
ok($rc, "> simple interface");

$rc = Proc::PID::File->running(
    verify => 1, name => "test", dir => "."
    );
ok($rc, "verified: real");

# WARNING: the following test takes over the pidfile from the
# daemon such that he cannot clean it up.  this is as it should be
# since no one but us should occupy our pidfile 

$rc = Proc::PID::File->running(
    verify => "falsetest", name => "test", dir => "."
    );
ok(! $rc, "verified: false");

sleep 1 while kill 0, $pid;

$rc = Proc::PID::File->running(name => "test", dir => ".");
ok(! $rc, "single instance");

#
# --- test OO interface ---------------------------------------------------
#

# test no one running

ok(1, "> OO interface");
ok(! $pf->alive(), "single instance");
ok($pf->read() == $$, "id read");
$pf->remove();
ok(! -f $pf->{path}, "pidfile removed");
exit(1) if -f $pf->{path};

# test someone running

system qq|./test.pl --daemon > /dev/null 2>&1 &|;
wait until -f $pf->{path};
ok(1, "write tested");
ok($pf->alive(), "second incarnation");

# test DESTROY

system qq|./test.pl --short > /dev/null 2>&1|;
ok(-f $pf->{path}, "destroy");

ok(1, "done");
