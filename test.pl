#!/usr/bin/perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# make sure test.pl can find the module without being run by 'make test'
use lib 'Iblib/arch';
use lib 'blib/lib';

# set up simple testing
use Test::Simple tests => 7;
use Proc::PID::File
ok(1, 'use Proc::PID::File'); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

$|++; $\ = "\n";

$pf = Proc::PID::File->new(
	dir => ".",
	name => "test",
	debug => $ENV{DEBUG}
	);

$pf->write(), sleep(30), exit()
	if shift eq "--daemon";

# test no one running

ok(! $pf->alive(), "Single instance");
ok($pf->read() == $$, "Read id");
$pf->remove();
ok(! -f $pf->{path}, "Remove tested");

# test someone running

unlink $pf->{path} || die qq/unable to remove pidfile: "$pf->{path}"/;
system qq|./test.pl --daemon > /dev/null 2>&1 &|;
wait until -f $pf->{path};
ok(1, "Write test");
ok($pf->alive(), "Second incarnation");
ok(1, "Done");
