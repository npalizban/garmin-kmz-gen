# garmin-kmz-gen

It is a perl script to generate KMZ files compatible with Garmin GPS devices.
By default it downloads the map tiles from openstreet map project: https://www.openstreetmap.org/.
You can change the url and use different layers as well.

Most garming decives usually have some limitations:

  - each image resolution can be at most 1024x1024 pixles.
  - there can be upto 100 images in total for a custom map file.

Therefore, to get most information in a map, 256x256 tiles are converted to 1024x1024 images and then referenced by kml file.
KMZ file is just the zipped version of KML file + images.

## Installation

No installation is needed.
Can download the perl script and just run it.

## Usage

./gen_kmz.pl --help

./gen_kmz.pl --kmz --name `generated-file-name` --zoom `zoom-level` --west `coord` --east `coord` --north `coord`  --south `coord`

Example: 

./gen_kmz.pl --kmz --name touchal --zoom 15 --west 51.26 --east 51.51 --north 35.94 --south 35.81


## Dependencies

Access to openstreetmaps (https://www.openstreetmap.org/)

curl (https://curl.se/)

imageMagic (https://linux.die.net/man/1/imagemagick)

If using linux, probably should already have above softwares installed.
