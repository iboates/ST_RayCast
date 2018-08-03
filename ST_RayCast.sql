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
	return_geom GEOMETRY;
	
BEGIN

	WHILE theta < 2*pi() LOOP

		adj = max_ray_dist * COS(theta);
		opp = max_ray_dist * SIN(theta);

		candidate_geom = ST_SetSRID(
			ST_Intersection(
				ST_SetSRID(
					ST_MakeLine(
						in_point,
						ST_SetSRID(ST_Point(adj, opp), 26910)
					),
					26910),
				in_boundaries
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
							in_point,
							ST_SetSRID(dp.geom, 26910)
						) ASC
					LIMIT 1);
				
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

	END LOOP;

	IF out_geom_type = 'POINT' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 1));
	ELSIF out_geom_type = 'LINESTRING' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 2));
	END IF;

END
$$
LANGUAGE plpgsql;

SELECT ST_AsEWKT(ST_RayCast(
	ST_SetSRID(ST_Point(0, 0), 26910),
	(SELECT ST_CollectionExtract(ST_Collect(geom), 2) FROM edge),
	out_geom_type := 'POINT',
	num_rays := 256,
	max_ray_dist := 70
));

DROP TABLE IF EXISTS circle_of_points;
CREATE TABLE circle_of_points AS (
	SELECT ST_RayCast(
		ST_SetSRID(ST_Point(0, 0), 26910),
		(SELECT ST_CollectionExtract(ST_Collect(geom), 2) FROM edge),
		out_geom_type := 'POINT',
		num_rays := 256,
		max_ray_dist := 70
	)
);

DROP TABLE IF EXISTS circle_of_lines;
CREATE TABLE circle_of_lines AS
	(SELECT ST_CollectionExtract(
		ST_RayCast(
			ST_SetSRID(ST_Point(0, 0), 26910),
			(SELECT ST_CollectionExtract(ST_Collect(geom), 2) FROM edge),
			out_geom_type := 'LINESTRING',
			num_rays := 256,
			max_ray_dist := 70
		),
		2
	))