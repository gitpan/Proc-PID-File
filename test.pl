#!/usr/bin/perl -w

#   make sure this script can find the module
#   without being run by 'make test' (see --deamon switch below).

use lib 'Iblib/arch';
use lib 'blib/lib';

#   set up expectations

use Test::Simple tests => 11;

$|++; $\ = "\n";
use Proc::PID::File
ok(1, 'use Proc::PID::File'); # If we made it this far, we're ok.

$pf = Proc::PID::File->new(
	dir => ".",
	name => "test",
	debug => $ENV{DEBUG}
	);

$pf->write(), sleep(30), exit()
	if (shift || "") eq "--daemon";

# test no one running

ok(! $pf->alive()
    , "Single instance"
    );
ok(! Proc::PID::File->running(name => "test", dir => ".")
    , "Simple interface"
    );
ok($pf->read() == $$, "Read id");
$pf->remove();
ok(! -f $pf->{path}, "Remove tested");
exit(1) if -f $pf->{path};

# test someone running

system qq|./test.pl --daemon > /dev/null 2>&1 &|;
wait until -f $pf->{path};
ok(1, "Write test");
ok($pf->alive(), "Second incarnation");

# test simple interface

$rc = Proc::PID::File->running(
    name => "test", dir => "."
    );
ok($rc, "Simple interface");

$rc = Proc::PID::File->running(
    verify => 1, name => "test", dir => "."
    );
ok($rc, "Verified - Real");

$rc = Proc::PID::File->running(
    verify => "falsetest", name => "test", dir => "."
    );
ok(! $rc, "Verified - False");

ok(1, "Done");
