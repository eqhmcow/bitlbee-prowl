#!/usr/bin/perl -w
use strict;
use warnings;

=pod
Design:

read bitlbee log file(s):
* lock log directory
* for each line, parse:
** recv or send
** nick (not mine)
** text
* for each line:
** check if a file already exists (check for nick.*)
*** if we're logging, append line to file
*** if we're not logging, create file and write line
**** file format: nick.YYYYMMDD-HH:MM:SS.dirty
* release lock
=cut

use Fcntl ':flock'; # import LOCK_* constants
use Date::Parse;
use Date::Format;
use Carp 'confess';

# lock log directory
my $LOG_DIR = "$ENV{HOME}/aimlog";
-d $LOG_DIR or mkdir $LOG_DIR or die "Couldn't make directory $LOG_DIR: $!";
open my $lock_file, '>>', "$LOG_DIR/.lock" or die "Can't open lock file: $!";
flock($lock_file, LOCK_EX);

my $NICK = 'bear';
while (<>) {
    my @parse;
    next unless @parse =
        m/^(\d+:\d+) <(?:\@?($NICK)> ([^:]+): |.([^>]+)> ($NICK): )(.*)$/;
    my ($time, $type, $nick, $text) = ($parse[0], $parse[1] ?
        ('send', $parse[2], $parse[5]) :
        ('recv', $parse[3], $parse[5]));
    write_log({
        'epoch' => str2time($time),
        'type'  => $type,
        'nick'  => $nick,
        'time'  => $time,
        'text'  => $text,
    })
}

sub write_log
{
    my %args = %{shift()};
    my $type = $args{'type'} or confess "Need a type";
    my $nick = $args{'nick'} or confess "Need a nick";
    my $epoch = $args{'epoch'} or confess "Need a epoch";
    my $time = $args{'time'} or confess "Need a time";
    my $text = $args{'text'};

    my $file = grab_log_file($nick, $epoch);
    print $file $type eq 'recv' ?
        "$time $nick: $text" :
        "$time $NICK: $text", "\n";
    return;
}

sub grab_log_file
{
    my ($nick, $epoch) = @_;
    my @files = glob("$LOG_DIR/$nick.*");
    # /home/user/aimlog/nick.20100103-11:06:00.dirty
    foreach (@files) {
        next unless m!^\Q$LOG_DIR/$nick.\E\d[^.]+(?:\.dirty)?$!;
        open my $file, '>>', $_ or die "Couldn't open file: $!";
        return $file;
    }
    # create new
    open my $file, '>', "$LOG_DIR/$nick." . time2str('%Y%m%d-%H:%M:%S', $epoch) .
        '.dirty' or die "Couldn't open file: $!";
    return $file;
}

# release lock
flock($lock_file, LOCK_UN);

