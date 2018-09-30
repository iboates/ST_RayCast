CREATE OR REPLACE FUNCTION ST_RayCast(
	in_point GEOMETRY,
	in_boundaries GEOMETRY,
	out_geom_type TEXT,
	num_rays INTEGER,
	max_ray_dist FLOAT
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

	IF out_geom_type NOT IN ('MULTIPOINT', 'MULTILINESTRING') THEN
		RAISE EXCEPTION 'Output geometry type (''%'') must be one of (''%'', ''%'')', out_geom_type, 'MULTIPOINT', 'MULTILINESTRING';
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
		IF out_geom_type = 'MULTIPOINT' THEN
			return_geom = ST_Collect(ST_CollectionExtract(return_geom, 1), candidate_geom);
		ELSIF out_geom_type = 'MULTILINESTRING' THEN
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
	IF out_geom_type = 'MULTIPOINT' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 1));
	ELSIF out_geom_type = 'MULTILINESTRING' THEN
		RETURN ST_Multi(ST_CollectionExtract(return_geom, 2));
	END IF;

END
$$
LANGUAGE plpgsql;
COMMENT ON FUNCTION ST_RayCast(
	GEOMETRY,
	GEOMETRY,
	TEXT,
	INTEGER,
	FLOAT
) IS 'Created by Isaac Boates. Use of this software is at the user''s own risk, and no responsibility is claimed by the creator in the event of damages, whether tangible or financial caused directly or indirectly by the use of this software.';