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

	/* Cast rays over the specified angle window */
	WHILE theta < 2*pi() LOOP

		candidate_geom = (
			/* Make a CTE for the casted ray endpoint so we only have to query it once */
			WITH
				ray
			AS (
				SELECT 
					/* Make a ray */
					ST_MakeLine(
						ST_Transform(
							ST_Project(
								/* PostGIS only allows projecting points in geographical CRS, so we have to do some transforming here */
								ST_Transform(
									in_point,
									4326
								)::geography,
								max_ray_dist,
								theta
							)::geometry,
							srid
						),
						in_point
					) AS geom
			)
			SELECT
				/* Intersect this ray with the input boundaries, ignore empty results (no ray intersection) */
				ST_Intersection(
					ST_MakeLine(
						ray.geom,
						in_point
					),
					in_boundaries
				) AS geom
			FROM
				ray
			WHERE
				NOT ST_IsEmpty(
					ST_Intersection(
						ST_MakeLine(
							ray.geom,
							in_point
						),
						in_boundaries
					)
				)
		);

		/* In the case of multiple ray intersections, take the closest one */
		IF ST_NumGeometries(candidate_geom) > 1 THEN
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

		/* Either prep the point for return or make a line out of it for return depending on user input */
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

		theta = theta + 2*pi() / num_rays;

	END LOOP;

	/* Return all the points or lines created */
	IF out_geom_type = 'POINT' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 1));
	ELSIF out_geom_type = 'LINESTRING' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 2));
	END IF;

END
$$
LANGUAGE plpgsql;

DROP TABLE IF EXISTS multi_rays;
CREATE TABLE multi_rays AS (
	SELECT
		p.id AS p_id,
		(SELECT ST_RayCast(
			p.geom,
			ST_CollectionExtract(ST_Collect(e.geom), 2),
			out_geom_type := 'POINT',
			num_rays := 8,
			max_ray_dist := 150
		)) AS geom
	FROM 
		point AS p,
		edge AS e
	GROUP BY
		p.id
)