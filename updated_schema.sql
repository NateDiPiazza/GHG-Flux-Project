-- This script will DROP the needed rows to complete the GHG flux project

--Dropping the previous entries area and ppm in favor of multiple gas columns

ALTER TABLE injections DROP COLUMN area;

ALTER TABLE injections DROP COLUMN ppm;


ALTER TABLE injections ADD COLUMN peak_start timestamp without time zone;

ALTER TABLE injections ADD COLUMN peak_end timestamp without time zone;

ALTER TABLE injections ADD COLUMN ch4_area real;

ALTER TABLE licor_samples ADD COLUMN sample_ppm real; --name changed from convention to avoid naming conflict

ALTER TABLE injections ADD COLUMN n2o_area real;

ALTER TABLE injections ADD COLUMN ch4_ppm real;

ALTER TABLE injections ADD COLUMN n2o_ppm real;

--Flag to check if a runs has been processed yet; (0 not yet) (1 yes)

ALTER TABLE runs ADD COLUMN processed integer DEFAULT 0 ;

CREATE TABLE flux_constant ( headspace real, molecular_weight real )

--ALTER TABLE injections DROP COLUMN peak_start;

--ALTER TABLE injections DROP COLUMN peak_end;

--ALTER TABLE injections DROP COLUMN ch4_area;

--ALTER TABLE licor_samples DROP COLUMN sample_ppm;

--ALTER TABLE injections DROP COLUMN n2o_area;

--ALTER TABLE injections DROP COLUMN ch4_ppm;

--ALTER TABLE injections DROP COLUMN n2o_ppm;

--ALTER TABLE injections DROP COLUMN processed;
