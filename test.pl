#!/usr/bin/perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# make sure test.pl can find the module without being run by 'make test'
use strict;
use warnings;

# set up simple testing
use Test::Simple tests => 8;
use Proc::PID::File;
ok(1, 'use Proc::PID::File'); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

$|++; $\ = "\n";

my $pf = Proc::PID::File->new(
	dir => ".",
	name => "test",
	debug => $ENV{DEBUG}
	);

# test no one running

ok(! $pf->alive(), "Single instance");
ok($pf->read() == $$, "Read id");
$pf->remove();
ok(! -f $pf->{path}, "Remove tested");

# test one other process running
ok(! $pf->alive(), "Single instance again");
ok($pf->read() == $$, "Read id is OK in parent");

if (my $pid = fork){
    # parent here
    sleep 3;
    ok($pf->read() == $$, "PID file not destroyed");
} else {
    $pf->alive();
    exit;
}

ok(1, "Done");
