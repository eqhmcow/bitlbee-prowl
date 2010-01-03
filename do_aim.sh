#!/bin/bash
$HOME/bin/new_lines.pl $HOME/irclogs/localhost2/\&bitlbee.log | $HOME/bin/parse_bitlbee_log.pl
$HOME/bin/parse_aim_logs.pl
