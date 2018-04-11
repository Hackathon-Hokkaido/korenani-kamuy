#!/usr/bin/perl

use strict;
use Carp;
use CGI;
use Time::HiRes qw(gettimeofday);
use File::Copy;
use File::Basename;
use File::Spec;
use lib qw(/usr/local/trail-life/lib/perl);
use Trail::Life;

# global config
my $queue_dir  = "/vol/data/trail-life";
my $base       = "/usr/local/trail-life";

my $charset    = "UTF-8";
my $id         = sprintf("%d.%d.%d", gettimeofday(), $$);
my $qnew_dir   = File::Spec->catfile($queue_dir, "incoming");
my $newfile    = File::Spec->catfile($qnew_dir,  $id);
my $target     = $newfile;

#
# MAIN
#
my $q = new CGI;
http_header_print($q);
# env_dump($q); # debug

# incoming
my $fh = $q->upload('upfile');
copy ($fh, $newfile);

# main
body_found_pre();
{
    # speculate the uploaded image.
    my $trail = new Trail::Life $base;
    if (my $type = $trail->is_valid_type($newfile)) {
	$target = $trail->rename_file($newfile, $type) || $target;
	$trail->speculate($target);
    }
}
body_found_post();

exit 0;


#
# debug
#

sub env_dump
{
    my ($query) = @_;

    my $buf = undef;
    while (my ($k,$v) = each %ENV) {
	printf("<!-- %s = %s -->\n", $k, $v);
    }
}


sub http_header_print
{
    my ($query) = @_;

    print $query->header(-type    => "text/html; charset=$charset",
			 -charset => $charset,
			 -target  => "_top");
}


sub body_found_pre
{
    print "<BODY BGCOLOR=\"#E6E6FA\">\n";
    print "<H1><CENTER>";
    print "<IMG SRC=\"http://www.nuinui.net/rudonikki/gomen.gif\"></IMG>\n";
}


sub body_found_post
{
    print "</CENTER></H1><HR>";
}
