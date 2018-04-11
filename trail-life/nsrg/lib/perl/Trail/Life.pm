#-*- coding:utf-8 mode:perl -*-
#
#  Copyright (C) 2018 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: @template.pm,v 1.13 2010/03/06 13:11:42 fukachan Exp $
#

package Trail::Life;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;
use FileHandle;

=head1 NAME

Trail::Life - the top level dispatcher

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new()

constructor.

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self, $dir) = @_;
    my ($type) = ref($self) || $self;
    my $me     = { _base_dir => $dir };
    return bless $me, $type;
}


sub base_dir
{
    my ($self) = @_;

    $self->{ _base_dir };
}


sub speculate
{
    my ($self, $img) = @_;
    
    my $base_dir  = $self->base_dir();
    my $python    = "/usr/bin/python";
    my $prog      = "$base_dir/models/tutorials/image/imagenet/classify_image.py";
    my $model_dir = "$base_dir/imagenet";
    
    my $rh = new FileHandle "$python $prog --model_dir $model_dir --image_file $img |";
    if (defined $rh) {
	my $buf;

      LINE:
	while ($buf = <$rh>) {
	    if ($buf =~ /^\s*(.*)\s*\(score\s+=\s+([\d\.]+)\)/) {
		my ($what, $score) = ($1, $2);
		my $p = int($score * 100);
		if ($p > 5) {
		    my ($j) = $self->edict_lookup($what);
		    my ($d) = $$j[0] || $what;
		    print "<p>確率 $p \%で\"${d}\"だと思うよ\n";
		}
	    }
	}
	$rh->close();
    }

    $self->show_note();
    $self->show_query();
    
    # [debug]
    #    loc_info -> twitter
    #    loc_info -> openstreemap
    $self->speculate_location($img); 
}


sub speculate_location
{
    my ($self, $img) = @_;

    my $rh = new FileHandle $img;
    if (defined $rh) {
	use Image::ExifTool;
	my $exif = Image::ExifTool->new->ImageInfo($rh);
	$rh->close();

	for my $k (sort keys %$exif) {
	    if ($k =~ /GPSPosition/i) {
		my ($lat, $lon);
		if ($exif->{ $k } =~ /(.*N),\s*(.*E)/) {
		    ($lat, $lon) = (_gps_str2num($1), _gps_str2num($2));
		    return sprintf("%s,%s", $lat, $lon);
		}
	    }
	}	    
    }
    else {
	print "warn: location info (cannot open)<br>\n";
    }
}


#  42 deg 59'  4.63" N
# 141 deg 27' 23.50" E
sub _gps_str2num
{
    my ($str) = @_;

    if ($str =~ /(\d+)\s+deg\s+(\d+)'\s+([\d\.]+)"\s+([NE])/) {
	my ($dd, $mm, $ss) = ($1, $2, $3);
	return ($dd + $mm/60 + $ss/3600);
    }
    else {
	return $str;
    }
}


sub is_valid_type
{
    my ($self, $file) = @_;
    
    use File::MMagic;
    my $mm   = new File::MMagic;
    my $type = $mm->checktype_filename($file);
    if ($type =~ /jpeg/) {
	return 'jpg';
    }
    return undef;
}


sub rename_file
{
    my ($self, $src, $type) = @_;

    my $dst = sprintf("%s.%s", $src, $type);
    unless (rename($src, $dst)) {
	print "error: cannot rename\n";
	return undef;
    };
    return $dst;
}


sub edict_lookup
{
    my ($self, $what) = @_;
    my (@r);
    
    my $base_dir   = $self->base_dir();
    my $edict_dir  = File::Spec->catfile($base_dir,  "share/edict");
    my $edict_file = File::Spec->catfile($edict_dir, "cooked.edict2.imagenet");

    $what =~ s/^\s*//;
    $what =~ s/\s*$//;
    my (@what) = split(/\s*,\s*/, $what);
    my ($pat)  = "";
    for my $w (@what) {
	$pat .= $pat ? "|/$w/" : "/$w/";
    }
    $self->do_log("edict_lookup: $what");
    $self->do_log("edict_lookup: pattern={$pat}");
    
    my $rh = new FileHandle $edict_file;
    if (defined $rh) {
	my $buf;
	while ($buf = <$rh>) {
	    if ($buf =~ /$pat/i) {
		if (my $found = $self->is_danger_pattern_found($pat)) {
		    $self->need_append_note($found);
		    $self->do_log("warn: $pat");
		}
		else {
		    $self->do_log("not danger: $pat");
		}
		my ($j) = split(/\//, $buf);
		my ($a) = split(/;/, $j);
		push(@r, $a);
	    }
	}
	$rh->close();
    }

    return \@r;
}


sub is_danger_pattern_found
{
    my ($self, $pat) = @_;

    # DEBUG: teddy bear
    # print "is_danger: $pat<br>\n";
    if ($pat =~ /\/(acorn|bee|bees|corn|teddy|teddy bear)\//) {
	return 1;
    }
    # HACK BY NSRG ; similar objects ;-)
    elsif ($pat =~ /\/(gyromitra|dung beetle)\//) {
	return 2;
    }

    return 0;
}


sub need_append_note
{
    my ($self, $flag) = @_;

    $self->{ _append_note } = $flag || 1;
}


sub show_note
{
    my ($self) = @_;

    return unless $self->{ _append_note };

    if ($self->{ _append_note } > 1) {
    print q{
<p>
野生動物のフンに似ているみたいです。
    }
    }

    print q{
<p>
ヒグマは消化がよくないので、
ドングリやトウモコロシ、ハチなどがフンの中にそのまま見えることがあります。
色やにおいも素材に近いようです。
くわしくは
<A HREF="http://www.city.sapporo.jp/kurashi/animal/choju/kuma/konseki/index.html">
「痕跡の見分け方」（札幌市）
</A>
や
<A HREF="http://www.city.asahikawa.hokkaido.jp/kurashi/271/299/303/p002794.html">
「ヒグマの痕跡の例」（旭川市）
</A>
などを参照してください。
    };
}


sub show_query
{
    my ($self) = @_;

    print q{
    <HR><A HREF="http://opendata.fml.org/korenani/">【もどる】</A>
    };
}


# debug
sub do_log
{
    my ($self, $pat) = @_;

    my $wh = new FileHandle ">> /var/tmp/log.tl";
    $wh->print($pat);
    $wh->close();
}

=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2018 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

Trail::Life appeared in the trail-life system as a part of 
Opendata Hokkaido Hachathon 2018.

=cut


1;
