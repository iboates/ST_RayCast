# ST_RayCast

## Overview

This is a PostGIS function that allows you to cast rays from point features to linestring or polygon features. Returned geometry can be of `MULTIPOINT` or `MULTILINESTRING` type. Parameters controlling the number of casted rays and the maximum ray distance are also be specified

## Installation

Execute the contents of `ST_RayCast.sql` as a query on your database. To confirm that it is working correctly, execute the contents of `test/ST_RayCast_test.sql` on your database. It will create the PostGIS extension if it does not already exist, as well as create some test data tables and run through a set of sample function calls, which should produce the following tables:

* **test_lines_pointoutput**: Result of casting rays towards linestrings and returning the result as a `MULTIPOINT` table.
* **test_lines_lineoutput**: Result of casting rays towards linestrings and returning the result as a `MULTILINESTRING` table.
* **test_polys_pointoutput**: Result of casting rays towards polygons and returning the result as a `MULTIPOINT` table.
* **test_polys_lineoutput**: Result of casting rays towards polygons and returning the result as a `MULTILINESTRING` table.

## Usage / Parameters

Call the function as you would any other PostGIS function. There are also sample function calls in `test/ST_RayCast_test.sql`. The parameters are as follows:

* `in_point GEOMETRY`: Input points from which to cast the rays. Must be of `POINT` type.
* `in_boundaries GEOMETRY`: Input linestrings against which the rays are casted. Must be of `LINESTRING` type. To use `POLYGON` geometries instead, wrap them in a call to `ST_ExteriorRing` (More specialized transformations may be necessary in the case of holes).
* `out_geom_type TEXT`: Type of desired output geometry. Must be one of `MULTIPOINT` or `MULTPOLYGON`.
* `num_rays INTEGER`: Number of rays to cast. Will be distributed equally 360° around the point.
* `max_ray_dist FLOAT`: Maximum distance that a ray may be cast. boundary features further away than this will not be "seen" by a point.

## Further Development

There are a couple of features that could augment this function. I hope to revisit this in the future to add them, but they may also serve as an opportunity to cut your teeth in PostGIS development for anyone who is willing, as I don't think they would be particularly hard:

* Add an offset parameter for the ray angles, i.e. Make the first ray start at a value other than 0° and have each subsequent ray also be casted with this offset value.
* Add a start and end angle for the ray angles, i.e. Allow for the raycasting to occur only within a specific angular window for "directional" sight.

## Credits

Developed by Isaac Boates (iboates@gmail.com) with [support](https://gis.stackexchange.com/questions/291527/project-a-point-onto-a-line-feature-at-a-given-angle-in-postgis-st-project-onl) from Stackoverflow user [ThingumaBob](https://gis.stackexchange.com/users/93656/thingumabob).
