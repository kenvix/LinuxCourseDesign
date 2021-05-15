CREATE TABLE sqlite_sequence(name,seq);
CREATE VIEW "everything" AS SELECT
	elements.*, 
	types.type, 
	types.subtype, 
	types.sku, 
	users.name, 
	users.studentid
FROM
	elements
	INNER JOIN
	types
	ON 
		elements.typeid = types.typeid
	INNER JOIN
	users
	ON 
		elements.userid = users.userid
/* everything(id,userid,typeid,x,y,date,type,subtype,sku,name,studentid) */;
CREATE TABLE IF NOT EXISTS "types" (
  "typeid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "type" TEXT NOT NULL DEFAULT '',
  "subtype" TEXT NOT NULL DEFAULT '',
  "sku" TEXT NOT NULL DEFAULT '',
  CONSTRAINT "unique_types" UNIQUE ("type" ASC, "subtype" ASC, "sku" ASC) ON CONFLICT ROLLBACK
);
CREATE TABLE IF NOT EXISTS "users" (
  "userid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "name" TEXT,
  "studentid" INTEGER NOT NULL,
  CONSTRAINT "unique_studentid" UNIQUE ("studentid") ON CONFLICT ROLLBACK
);
CREATE UNIQUE INDEX "i_studentid"
ON "users" (
  "studentid" COLLATE BINARY ASC
);
CREATE TABLE IF NOT EXISTS "elements" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "userid" integer NOT NULL,
  "typeid" integer NOT NULL,
  "x" real NOT NULL,
  "y" real NOT NULL,
  "date" TEXT NOT NULL DEFAULT CURRENT_DATE,
  CONSTRAINT "fk_userid" FOREIGN KEY ("userid") REFERENCES "users" ("userid") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "fk_typeid" FOREIGN KEY ("typeid") REFERENCES "types" ("typeid") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "unique_element" UNIQUE ("userid", "typeid", "x", "y", "date") ON CONFLICT ROLLBACK
);
CREATE INDEX "i_location"
ON "elements" (
  "x" ASC,
  "y" ASC
);
CREATE INDEX "i_type"
ON "elements" (
  "typeid" ASC
);
CREATE INDEX "i_userid"
ON "elements" (
  "userid" ASC
);
CREATE VIEW "daily_rank_by_type" AS SELECT
	t1.type, 
	t1.subtype, 
	t1.userid, 
	t1.name, 
	t1.studentid,
	t1.date, 
	(
		SELECT COUNT(*) 
		FROM everything AS t2
		WHERE 
			t2.userid = t1.userid 
			AND t2.type = t1.type 
			AND (t2.subtype = t1.subtype OR (t1.subtype IS NULL AND t2.subtype IS NULL))
			and t2.date = t1.date
	) AS subtype_count,
	t1.typeid
FROM
	everything AS t1
GROUP BY
	subtype, 
	type, 
	userid,
	date
/* daily_rank_by_type(type,subtype,userid,name,studentid,date,subtype_count,typeid) */;
CREATE VIEW "everything_merged" AS SELECT *, COUNT(*) AS kill_num FROM everything GROUP BY typeid, userid, x, y
/* everything_merged(id,userid,typeid,x,y,date,type,subtype,sku,name,studentid,kill_num) */;
CREATE VIEW "everything_unique_types" AS SELECT type, subtype, x, y, (
	CASE
		WHEN subtype IS NULL OR subtype = '' THEN type
		ELSE subtype
	END
) AS rtype, (
	CASE (
		CASE
			WHEN subtype IS NULL OR subtype = '' THEN type
			ELSE subtype
		END
		)
		WHEN '独眼巨人西诺克斯' THEN '👽'
		WHEN '岩石巨人' THEN '🗿'
		WHEN '神庙' THEN '🏯'
        WHEN '半人马莱尼尔' THEN '🐴'
        WHEN '莫尔德拉吉克' THEN '👻'
		WHEN '克洛格种子' THEN '🌱'
		ELSE '❓'
	END
) AS emoji FROM everything GROUP BY x, y
/* everything_unique_types(type,subtype,x,y,rtype,emoji) */;
