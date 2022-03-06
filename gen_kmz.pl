#!/usr/bin/perl

use strict;
use warnings;
use Math::Trig;
use Getopt::Long;

sub print_help {

    print "\n\n";
    print "
        Use this script to generate KMZ or KML map files which can be loaded to Garmin
        GPS devices custom map.

        ./script.pl [options]

        --name   Specify generated file's name

        Specify coordinate box with below options:

        --west   Specifies west edge coordinate
                 default: 
        --east   Specifies east edge coordinate
        --north  Specifies north edge coordinate
        --south  Specifies south edge coordinate
        --zoom   Specifies map zoom level 
                 default: 15

        Map tiles are selected such entered coordinates are included in the map

	--kmz    To also generate the zip KMZ file

        --url    Specify source URL to download the tiles from.

        --res    Image resolution. By default each image is 1024x1024 pixels and combined from attaching 
                 16 256x256 pixle tile images. 
                 Garming devices have a limit on each image resolution, and a limit on number of images
                 in a custom map. To get the most information it's good to max out each tile resolution.

                 possible values: 256, 512, 1024, ....

                 default: 1024


        --help   Print help menu

	Example usage:

	./script.pl --kmz --name touchal --zoom 15 --west 51.26 --east 51.51 --north 35.94 --south 35.81
  
    ";
    print "\n\n";
}

sub coord_to_index {
    my $latitude = $_[0];
    my $longitude = $_[1];
    my $zoom = $_[2];

    my $n = 2.0 ** $zoom;
    my $h_index = int(($longitude + 180.0) / 360.0 * $n);
    my $y_index = int((1.0 - asinh(tan($latitude * pi / 180.0)) / pi) / 2.0 * $n);
    return ($h_index, $y_index);
}


sub index_to_coord {
    my $h_index = $_[0];
    my $y_index = $_[1];
    my $zoom = $_[2];

    my $n = 2.0 ** $zoom;
    my $longitude = $h_index / $n * 360.0 - 180.0;
    my $latitude = atan(sinh(pi * (1 - 2 * $y_index / $n))) * 180 / pi;

    return ($latitude, $longitude)
}


my $zoom  = 15;
my $west  = 51.26;
my $east  = 51.51;
my $north = 35.94;
my $south = 35.81;
my $name  = 'map';
my $res   = 1024;
my $kmz   = '';
my $help  = '';

# Please set this param to interested map layer.
#my $url        = 'https://tile.openstreetmap.org';
#my $url_suffix = '';

my $url        = 'https://a.tile.thunderforest.com/cycle/';
my $url_suffix = '?apikey=6170aad10dfd42a38d4d8c709a536f38';

GetOptions(
  'help'    => \$help,
  'zoom=i'  => \$zoom,
  'west=f'  => \$west, 
  'east=f'  => \$east,
  'north=f' => \$north,
  'south=f' => \$south,
  'name=s'  => \$name,
  'res=i'   => \$res,
  'kmz'     => \$kmz,

  'url=s'   => \$url,
  'url_suffix=s' => \$url_suffix
);


if ($help)
{
    print_help;
    exit 0;
}

############################
##### validate options #####
############################

if ($res != 256 and $res != 512 and $res != 1024)
{
    print "entered res $res is not valid. Supported values: 256, 512, 1024.\n";
    exit 1;
}

my $ratio = $res / 256; # downloaded tiles are 256x256 pixle.
my $filename = "doc.kml";

##################################
##### calculate tile indexes #####
##################################

my ($first_h_index, $first_v_index)  = coord_to_index $north, $west, $zoom;
my ($last_h_index, $last_v_index)  = coord_to_index $south, $east, $zoom;

$last_h_index += $ratio - (($last_h_index - $first_h_index + 1) % $ratio);
$last_v_index += $ratio - (($last_v_index - $first_v_index + 1) % $ratio);

my $num_of_h_images = ($last_h_index - $first_h_index + 1) / $ratio;
my $num_of_v_images = ($last_v_index - $first_v_index + 1) / $ratio;

my $num_of_images = $num_of_h_images * $num_of_v_images;
my $number_of_tiles = $num_of_images * $ratio * $ratio;

if ( $num_of_images > 100)
{
    print "WARNING number of images passes 100 Garmin device limit.\n";
    print "number of images = $num_of_h_images x $num_of_v_images = $num_of_images\n";
    print "Script will continue and generate a kml file, but it might not work on the device\n";
    sleep(5);
}

#####################################
##### start making the map file #####
#####################################

open(FH, '>', $filename) or die $!;
print FH "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\n";
print FH "<kml xmlns=\"http://earth.google.com/kml/2.1\">\n";
print FH "<Document>\n";
print FH "<name>$name-$zoom</name>\n";

system "rm -rf images && mkdir images";
system "rm -rf *.png";

my $count=0;

for (my $h_index = 0; $h_index < $num_of_h_images; $h_index++) 
{
    for (my $v_index = 0; $v_index < $num_of_v_images; $v_index++)
    {
	my $w = 0;
	my $e = 0;
	my $n = 0;
	my $s = 0;

        my @comb_tiles = ();

        for (my $i = 0; $i < $ratio; $i++)
	{
	    my @tiles = ();
	    for (my $j = 0; $j < $ratio; $j++)
	    {
		my $tile_h_index = $h_index * $ratio + $i;
		my $tile_v_index = $v_index * $ratio + $j;

		my $tile_h_id = $first_h_index + $h_index * $ratio + $i;
		my $tile_v_id = $first_v_index + $v_index * $ratio + $j;

		$count++;
		print "downloading tile $count out of $number_of_tiles --> ${\int(100.0 * $count / $number_of_tiles)} %\n";
		my $exit_code = system "curl -s $url/$zoom/$tile_h_id/$tile_v_id.png$url_suffix -o tile-$i-$j.png";
                if ($exit_code != 0)
                {
                    print "Could not download tiles, please check URL\n";
		    exit 2;
                }

                push(@tiles, "tile-$i-$j.png");

		if ($i == 0 && $j == 0) # north west inner tile
		{
		    ($n, $w) = index_to_coord $tile_h_id, $tile_v_id, $zoom;
		}
		elsif ($i == $ratio - 1 && $j == $ratio - 1) # south east inner tile
		{
                    ($s, $e) = index_to_coord $tile_h_id + 1, $tile_v_id + 1, $zoom;
		}
	    }
	    my $exit_code = system "convert -append ${\join(' ', @tiles)} comb-tile-$i.png";
            if ($exit_code != 0)
            {
                print "Could not combine tiles, please check URL\n";
	        exit 3;
            }

            push(@comb_tiles, "comb-tile-$i.png"); 
	    system "rm -rf tile*";
	}
	system "convert +append ${\join(' ', @comb_tiles)} comb-$h_index-$v_index.png";
	system "rm -rf comb-tile*.png";

	# convert to JPG format since garmin only supports JPG
	my $image_name = "image-$h_index-$v_index";
	system "convert comb-$h_index-$v_index.png images/$image_name.jpg";
	system "rm -rf comb*.png";


        print FH "<GroundOverlay>\n";
        print FH "  <name>$image_name</name>\n";
        print FH "  <Icon><href>images/$image_name.jpg</href></Icon>\n";
        print FH "  <LatLonBox>\n";
        print FH "    <north>$n</north>\n";
        print FH "    <south>$s</south>\n";
        print FH "    <west>$w</west>\n";
        print FH "    <east>$e</east>\n";
        print FH "  </LatLonBox>\n";
        print FH "</GroundOverlay>\n";
    }
}

print FH  "</Document>\n";
print FH  "</kml>\n";

close(FH);

if ($kmz)
{
    system "zip -r $name.kmz doc.kml images";
}
