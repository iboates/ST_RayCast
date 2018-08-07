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
	srid INTEGER = ST_SRID(in_point);
	candidate_geom GEOMETRY;
	return_geom GEOMETRY;
	
BEGIN

	/* Do preliminary checks for common problems */

	IF ST_SRID(in_boundaries) != srid THEN
		RAISE EXCEPTION 'SRID of input points (%) does not match input boundaries SRID (%)', ST_SRID(in_point), ST_SRID(in_boundaries);
	END IF;

	WHILE theta < 2*pi() LOOP

		adj = max_ray_dist * COS(theta);
		opp = max_ray_dist * SIN(theta);

		candidate_geom = ST_Intersection(
			ST_MakeLine(
				in_point,
				ST_SetSRID(ST_Point(adj, opp), srid)
			),
			in_boundaries
		);

		IF NOT ST_IsEmpty(candidate_geom) THEN

			IF ST_GeometryType(candidate_geom) = 'ST_MultiPoint' THEN

				candidate_geom = (
					SELECT
						dp.geom
					FROM
						ST_DumpPoints(candidate_geom) AS dp
					ORDER BY
						ST_Distance(
							in_point,
							dp.geom
						) ASC
					LIMIT 1
				);
				
			END IF;

			IF out_geom_type = 'POINT' THEN
				return_geom = ST_Collect(ST_CollectionExtract(return_geom, 1), candidate_geom);
			ELSIF out_geom_type = 'LINESTRING' THEN
				return_geom = ST_Collect(
					ST_CollectionExtract(
						return_geom,
						2
					),
					ST_MakeLine(in_point, candidate_geom)
				);
			END IF;
			
		END IF;

		theta = theta + 2*pi() / num_rays;
-- 		INSERT INTO interm_result (geom) VALUES (ST_MakeLine(in_point, candidate_geom));

	END LOOP;

	IF out_geom_type = 'POINT' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 1));
	ELSIF out_geom_type = 'LINESTRING' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 2));
	END IF;

	RAISE NOTICE '%', ST_AsEWKT(candidate_geom);

END
$$
LANGUAGE plpgsql;

-- DROP TABLE IF EXISTS circle_of_points;
-- CREATE TABLE circle_of_points AS (
-- 	SELECT ST_RayCast(
-- 		ST_SetSRID(ST_Point(0, 0), 26910),
-- 		(SELECT ST_CollectionExtract(ST_Collect(geom), 2) FROM edge),
-- 		out_geom_type := 'POINT',
-- 		num_rays := 256,
-- 		max_ray_dist := 70
-- 	)
-- );

-- DROP TABLE IF EXISTS circle_of_lines;
-- CREATE TABLE circle_of_lines AS
-- 	(SELECT ST_CollectionExtract(
-- 		ST_RayCast(
-- 			(SELECT ST_CollectionExtract(ST_Collect(geom), 1) FROM point),
-- 			(SELECT ST_CollectionExtract(ST_Collect(geom), 2) FROM edge),
-- 			out_geom_type := 'LINESTRING',
-- 			num_rays := 256,
-- 			max_ray_dist := 70
-- 		),
-- 		2
-- 	))

DROP TABLE IF EXISTS interm_result;
CREATE TABLE interm_result ( 
	id INTEGER
);
SELECT AddGeometryColumn('interm_result', 'geom', 26910, 'GEOMETRY', 2);

DROP TABLE IF EXISTS multi_rays;
CREATE TABLE multi_rays AS (
	SELECT
		p.id AS p_id,
		(SELECT ST_RayCast(
			p.geom,
			ST_CollectionExtract(ST_Collect(e.geom), 2),
			out_geom_type := 'LINESTRING',
			num_rays := 8,
			max_ray_dist := 150
		)) AS geom
	FROM 
		point AS p,
		edge AS e
	GROUP BY
		p.id
)