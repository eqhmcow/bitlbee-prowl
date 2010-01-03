#!/usr/bin/perl -w
use strict;
use warnings;

=pod
Design:

read log directory:
* lock log directory
* for dirty files:
** send notice (prowl, fall back to email)
** move (rename) file, removing .dirty suffix
* for clean files:
** if timestamp is >= 5 minutes old, move (rename) file, adding .mail suffix
* for mail files:
** mail file to user
** remove file
* release lock
=cut

use Fcntl ':flock'; # import LOCK_* constants
use Carp 'confess';
use WebService::Prowl;
use File::Slurp;

my $PROWL_KEY = 'prowl key goes here';

# lock log directory
my $LOG_DIR = "$ENV{HOME}/aimlog";
-d $LOG_DIR or mkdir $LOG_DIR or die "Couldn't make directory $LOG_DIR: $!";
open my $lock_file, '>>', "$LOG_DIR/.lock" or die "Can't open lock file: $!";
flock($lock_file, LOCK_EX);

while (glob("$LOG_DIR/*.dirty")) {
    my ($nick) = m!^\Q$LOG_DIR/\E(.*)\.\d[^.]+\.dirty$!;
    next unless $nick;
    my $text = read_file($_);
    eval { put_on_notice($nick, $text) };
    die "Couldn't put $nick on notice: $@" if $@;
    my $file = $_;
    $file =~ s/\.dirty$//;
    rename ($_, $file) or die "Couldn't rename $_: $!"
}

while (glob("$LOG_DIR/*")) {
    next unless m!^\Q$LOG_DIR/\E.*\.\d[^.]+$!;
    next unless -M >= 5/1440;
    rename ($_, "$_.mail") or die "Couldn't rename $_: $!"
}

while (glob("$LOG_DIR/*.mail")) {
    my ($nick) = m!^\Q$LOG_DIR/\E(.*)\.\d[^.]+\.mail$!;
    next unless $nick;
    my $text = read_file($_);

    open my $mail, '|-', 'mail -s "AIM chat with ' . $nick . '" ' . $ENV{USER}
        or die "Couldn't shell to mail: $!";
    print $mail "$text\n";

    unlink $_ or die "Couldn't unlink $_: $!";
}

sub put_on_notice
{
    no strict 'refs';
    foreach (qw/prowl email/) {
        my $result;
        eval { $result = &{$_}(@_) };
        die if $@;
        $result and return 1;
    }
    return 0;
}

my $WS;
sub prowl
{
    my $ws = $WS;
    unless ($ws) {
        $ws = WebService::Prowl->new(apikey => $PROWL_KEY);
        $ws->verify or die "Couldn't verify prowl key: " . $ws->error();
        $WS = $ws;
    }
    $ws->add(
        application => "AIM",
        event       => $_[0],
        description => $_[1],
    );
    return 1;
}

sub email
{
    # just shell out
    open my $mail, '|-', 'mail -s "AIM chat with ' . $_[0] . '" ' . $ENV{USER}
        or die "Couldn't shell to mail: $!";
    print $mail "$_[1]\n";
    return 1;
}

# release lock
flock($lock_file, LOCK_UN);
