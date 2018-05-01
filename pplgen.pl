#!/usr/bin/perl

# atrsoftgmbh 2018
# free use under the apache 2.0 license

# usage : pplgen realdir listname targetdir titlehint

# generate the ppl file for the target directory.
# the ppl is a text fiel for the so called teac p90 sd dac
# we use it as an better wav player ...

$dir = shift;


if ($dir eq ''
    || $dir eq '-h'
    || $dir eq '--help'
    || ! -d $dir) {
    &usage;
    exit(1);
}

$out = shift ;

if ($out eq '') {
    $out = &genoutname ($dir);
}

$tdir = shift;

$hint = shift;

if (!defined $tdir || $tdir eq '') {
    $tdir = "C:\\MUSIC";
}

%cd = ();

@o = ();

my $dh ;

opendir($dh, $dir) or die "cannot open $dir for read\n";

my @f = readdir($dh);

closedir($dh);

# we have all the info in.

@titel = &gentitle($dir, $hint);

# we have the facts now. lets check for the tracks and for data ...

foreach my $f (@f) {

    if ($f =~ m:[\d][\d][^\s]*\.wav$:) {
	# we have a wav file in

	&process_wav($f, $dir, \@f,\%cd, $tdir, \@titel);
    }
}

# we have the last to do, gen the thing

($prefix,$suffix) = &gen_teac_p90sd_ppl(\%cd, \@o);

# now we simply write the thing into the target diretory

my $ofh;

my $op = $dir . '/' . $out . '.' . $suffix;

open ($ofh, ">$op") or die "cannot open $dir/$out for write ... \n";

# print the prefix - if any
if ($prefix ne '') {
    print $ofh $prefix ;
}
 
foreach my $line (@o) {
    print $line . "\n"; # on screen please ...
    print $ofh $line . "\r\n";
}

close $ofh;

exit (0);

# end of main

sub gen_teac_p90sd_ppl {
    my $i_r = shift;

    my $o_r = shift;


    # the teac p90 sd use this format :
    # komma separated fields, no spacesoutside
    #
    # feld 1
    # string, delimited mit "
    # value : pfad zum titel
    # im player C:\ ; dann pfad in dos format # beachrte grosses C
    #
    # feld 2
    # zahl
    # value 2 (kanal ? )
    #
    # feld 3
    # string, delimited mit "
    # value title
    #
    # feld 4
    # string, delimited mit "
    # artist
    #
    # feld 5
    # zahl
    # value länge stück in sektoren, siehe info aus ribs ..
    #
    # feld 6
    # zahl
    # value rest sektoren, siehe info aus ribs
    #
    # feld 7
    # zahl
    # value vermutlich letzter benutzter index in titel

    foreach my $t (sort keys %{$i_r}) {
	my $i = $i_r->{$t};

	my $e = '';
	
	$e .= '"' . $i->{path} . '"';
	$e .= ',';

	$e .= $i->{channels};
	$e .= ',';

	$e .= '"' . $i->{title} . '"';
	$e .= ',';

	$e .= '"' . $i->{artist} . '"';
	$e .= ',';

	$e .= $i->{sectors};
	$e .= ',';

	$e .= $i->{rest};
	$e .= ',';

	$e .= $i->{end};

	push @{$o_r}, $e;
    }

    my $prefix  = chr(0xef) . chr(0xbb) . chr(0xbf); # we are in a ascii world 
    
    return ($prefix, 'ppl'); # the suffix for teac
}

sub gentitle {

    my $d = shift ;

    my $h = shift;
    
    # we generate the artist and album name. used in ppl
    my @p = split(/\//, $d);

    if ($#p < 1) {
	die "cannot work with less than one directory level fro artist/album...\n";
    }
    
    my $album_dir = pop @p;

    my $artist_dir = pop @p;

    my $artist = &norm($artist_dir);

    my $album = &norm($album_dir);

    
    return ($artist, $album, $artist_dir, $album_dir);
}

sub genoutname {
    my $dir = shift;

    my ($art,$alb,$artist_dir, $album_dir) = &gentitle ($dir, '');

    return $artist_dir . '_' . $album_dir;
}
    
sub process_wav {
    my $c = shift;

    my $p = shift;

    my $d_r = shift;

    my $cd_r = shift;

    my $targetdir = shift;
    
    my $titel_r = shift ;
    
    $c =~ m:([\d][\d])[^\s]*\.wav$:;

    my $tnr = $1;

    # we have the tracknam. now get the inf file

    my $inf = &get_inf_for_track($tnr, $d_r);

    &fillinfos($c, $tnr, $p, $inf, $cd_r, $targetdir, $titel_r);
}

sub fillinfos {
    my $c = shift;

    my $tnr = shift;

    my $p = shift;
  
    my $inf = shift;
    
    my $cd_r = shift;

    my $targetdir = shift;

    my $titel_r = shift;
    
    my ($sectors, $rest, $channels, $titel) = &read_inf($p, $inf);

    my $endindex = $sectors - $rest - 1; # teac use a index here ...
    
    my $fulltitel = $tnr . ' ' . $titel_r->[1] ;

    if ($titel ne '') {
	$fulltitel = &norm($titel) ;
    }

    my $artist = $titel_r->[0];

    # this is bad. depends on player .. for now ...
    my $tpath = $targetdir . '\\' . $titel_r->[2] . '\\' . $titel_r->[3] . '\\' . $c ; # '"

	
    my %entry = ('path' => $tpath,
		 'channels' => $channels,
		 'title' => $fulltitel,
		 'artist' => $artist,
		 'sectors' => $sectors,
		 'rest' => $rest,
		 'end' => $endindex
		 );

    $cd_r->{$tnr} = \%entry; 
}

sub norm {
    my $v = shift;

    $v =~ s:_: :g;
    $v =~ s:ä:ae:g;
    $v =~ s:ö:oe:g;
    $v =~ s:ü:ue:g;
    $v =~ s:ß:ss:g;
    $v =~ s:Ä:Ae:g;
    $v =~ s:Ö:Oe:g;
    $v =~ s:Ü:Ue:g;

    return $v;
}

sub get_inf_for_track {
    my $tnr = shift;

    my $d_r = shift;

    my $sre = qr/$tnr\.inf/;
    
    foreach my $f (@{$d_r}) {

       
	if ($f =~ m:$sre:) {
	    return $f;
	}
    }

    die "cannot find a proper inf file fro track $tnr, give up...\n";
}

sub read_inf {
   my $path = shift;
   my $inffile = shift;

   my $sectors = 1;
   my $rest = 0;
   my $channels= 1;
   my $titel = '';


   my $ifh;

   my $icedax = 0;

   my $inf = $path . '/' . $inffile;
   
   open($ifh, "$inf") or die "cannot open the $inf ... \n";

   while (<$ifh>) {
       if ( m:created by icedax: ) {
	   $icedax = 1;
	   last;
       }
   }

   if ($icedax == 0) {
       die "cannot find icedax for $inf ...\n";
   } else {
       open($ifh, "$inf") or die "cannot open the $inf ... \n";

       while (<$ifh>) {
	   if ( m:^Tracktitle[\s]*=[\s]*'(.*)': ) {
	       $titel = $1;
	       next;
	   }
	   if ( m:^Tracklength[\s]*=[\s]*([\d]+),[\s]*([\d]+): ) {
	       $sectors = $1;
	       $rest = $2;
	       next;
	   }
	   if ( m:^Channels[\s]*=[\s]*([\d]+): ) {
	       $channels = $1;
	       next;
	   }
       }
   }
       
   
   close $ifh;

   
   
   return ($sectors, $rest, $channels, $titel);
}

sub usage {
    print 'usage : perl pplgen.pl realdir [listname [targetdir [titlehint]]]
realdir : path to the music directory, at least level artist/album must be in at last...
listname : name for the playlist, in case teac ppl autoadded
targetdir : if for any reason not c:\\music ... 
titelhint : if for any reason not the titel from path ... 

reminder:
maximum 100 playlists in firmware 1.30 (cover about 48 gb wav )
read in alphabetic ...
need a rescan to recognise it ...
max 16 characters in the teac playlist selector ... short is beautiful ...

example:
cd  to_base_of_music
perl pplgen.pl norah_jones/the_fall # will make a list full name - too long
perl pplgen.pl norah_jones/the_fall norah_the_fall # shorter list
perl pplgen.pl norah_jones/the_fall norah_the_fall "d:\seconddisk" # if they ever do it ...
perl pplgen.pl norah_jones/the_fall norah_the_fall "C:\MUSIC" hugohint # iand a hint..
';
}
# end of file
