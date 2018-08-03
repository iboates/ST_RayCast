-- DROP TABLE IF EXISTS circle_of_points;
-- CREATE TABLE circle_of_points (
-- 	id SERIAL
-- );
-- SELECT AddGeometryColumn('circle_of_points', 'geom', 26910, 'POINT', 2 );
-- 
-- DROP TABLE IF EXISTS circle_of_lines;
-- CREATE TABLE circle_of_lines (
-- 	id SERIAL
-- );
-- SELECT AddGeometryColumn('circle_of_lines', 'geom', 26910, 'LINESTRING', 2 );

-- DO

CREATE OR REPLACE FUNCTION ST_RayCast(
	in_point GEOMETRY,
	in_boundaries GEOMETRY,
	out_geom_type TEXT DEFAULT 'POINT',
	num_rays INTEGER DEFAULT 32,
	max_ray_dist FLOAT DEFAULT 1000
)

RETURNS GEOMETRY AS

$$
DECLARE
	adj FLOAT;
	opp FLOAT;
	theta FLOAT = 0;
	candidate_geom GEOMETRY;
BEGIN

	WHILE theta < 2*pi() LOOP

		adj = 100 * COS(theta);
		opp = 100 * SIN(theta);

		candidate_geom = ST_SetSRID(
			ST_Intersection(
				ST_SetSRID(
					ST_MakeLine(
						ST_Point(0, 0),
						ST_Point(adj, opp)
					),
					26910),
				(SELECT ST_CollectionExtract(ST_Collect(geom), 2) FROM edge)
			),
			26910
		);

		IF NOT ST_IsEmpty(candidate_geom) THEN

			IF ST_GeometryType(candidate_geom) = 'ST_MultiPoint' THEN

				candidate_geom = (
					SELECT
						ST_AsEWKT(dp.geom)
					FROM
						ST_DumpPoints(candidate_geom) AS dp
					ORDER BY
						ST_Distance(
							ST_SetSRID(ST_Point(0, 0), 26910),
							ST_SetSRID(dp.geom, 26910)
						) ASC
					LIMIT 1);
				
			END IF;

		
			INSERT INTO circle_of_points(geom) VALUES (candidate_geom);

			INSERT INTO circle_of_lines(geom) VALUES (
				ST_MakeLine(
					candidate_geom,
					ST_SetSRID(ST_Point(0, 0), 26910)
				)
			);
			
		END IF;

		theta = theta + 2*pi()/256;

	END LOOP;

END
$$
LANGUAGE plpgsql;

-- SELECT ST_AsEWKT(ST_CollectionExtract(ST_Collect(geom), 2)) FROM edge