-- Nursing Workforce & Staffing Analysis
-- CMS Payroll-Based Journal (PBJ) Daily Nurse Staffing — Q1 2026
-- Consolidated SQL Analysis: Queries 01–22


-- ============================================================================
-- Query 01: Raw Data Validation
-- ============================================================================
SELECT
  COUNT(*) AS total_raw_rows
FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`;


-- ============================================================================
-- Query 02: Duplicate Facility Date Check
-- ============================================================================
SELECT
  PROVNUM,
  WorkDate,
  COUNT(*) AS record_count
FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`
GROUP BY
  PROVNUM,
  WorkDate
HAVING
  COUNT(*) > 1
ORDER BY
  record_count DESC;


-- ============================================================================
-- Query 03: Missing Value Check
-- ============================================================================
SELECT
  COUNTIF(PROVNUM IS NULL) AS missing_facility,
  COUNTIF(WorkDate IS NULL) AS missing_date,
  COUNTIF(MDScensus IS NULL) AS missing_census,
  COUNTIF(Hrs_RN IS NULL) AS missing_RN_hours,
  COUNTIF(Hrs_LPN IS NULL) AS missing_LPN_hours,
  COUNTIF(Hrs_CNA IS NULL) AS missing_CNA_hours
FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`;


-- ============================================================================
-- Query 04: Census Sanity Check
-- ============================================================================
SELECT
  MIN(MDScensus) AS minimum_residents,
  MAX(MDScensus) AS maximum_residents,
  AVG(MDScensus) AS average_residents,
  COUNTIF(MDScensus = 0) AS zero_resident_days
FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`;


-- ============================================================================
-- Query 05: Negative Staffing Hours Check
-- ============================================================================
SELECT
  COUNTIF(Hrs_RN < 0) AS negative_RN_hours,
  COUNTIF(Hrs_LPN < 0) AS negative_LPN_hours,
  COUNTIF(Hrs_CNA < 0) AS negative_CNA_hours
FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`;


-- ============================================================================
-- Query 06: Staffing Hours Summary
-- ============================================================================
SELECT
  AVG(Hrs_RN) AS avg_RN_hours,
  MAX(Hrs_RN) AS max_RN_hours,
  AVG(Hrs_LPN) AS avg_LPN_hours,
  MAX(Hrs_LPN) AS max_LPN_hours,
  AVG(Hrs_CNA) AS avg_CNA_hours,
  MAX(Hrs_CNA) AS max_CNA_hours
FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`;


-- ============================================================================
-- Query 07: Create Clean Staffing Table
-- ============================================================================
CREATE OR REPLACE TABLE
`projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean` AS

SELECT
  PROVNUM,
  PROVNAME,
  STATE,
  WorkDate,
  MDScensus,

  -- Total hours by nursing role
  Hrs_RN,
  Hrs_LPN,
  Hrs_CNA,

  -- Employee hours
  Hrs_RN_emp,
  Hrs_LPN_emp,
  Hrs_CNA_emp,

  -- Contract hours
  Hrs_RN_ctr,
  Hrs_LPN_ctr,
  Hrs_CNA_ctr,

  -- Total nursing hours
  (Hrs_RN + Hrs_LPN + Hrs_CNA) AS total_nursing_hours,

  -- Total employee nursing hours
  (Hrs_RN_emp + Hrs_LPN_emp + Hrs_CNA_emp)
    AS employee_nursing_hours,

  -- Total contract nursing hours
  (Hrs_RN_ctr + Hrs_LPN_ctr + Hrs_CNA_ctr)
    AS contract_nursing_hours,

  -- Hours per Resident Day
  CASE
    WHEN MDScensus > 0 THEN
      (Hrs_RN + Hrs_LPN + Hrs_CNA) / MDScensus
    ELSE NULL
  END AS HPRD,

  -- Share of nursing hours supplied by contractors
  SAFE_DIVIDE(
    (Hrs_RN_ctr + Hrs_LPN_ctr + Hrs_CNA_ctr),
    (Hrs_RN + Hrs_LPN + Hrs_CNA)
  ) AS contract_reliance

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_raw`;


-- ============================================================================
-- Query 08: Clean Table Validation
-- ============================================================================
SELECT
  COUNT(*) AS clean_rows,
  COUNTIF(total_nursing_hours IS NULL) AS missing_total_hours,
  COUNTIF(HPRD IS NULL) AS missing_HPRD
FROM
`projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`;


-- ============================================================================
-- Query 09: Staffing Component Validation
-- ============================================================================
SELECT
  COUNT(*) AS total_rows,

  COUNTIF(
    ABS(
      total_nursing_hours -
      (employee_nursing_hours + contract_nursing_hours)
    ) > 0.01
  ) AS component_mismatches,

  ROUND(
    MAX(
      ABS(
        total_nursing_hours -
        (employee_nursing_hours + contract_nursing_hours)
      )
    ),
    2
  ) AS largest_difference

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`;


-- ============================================================================
-- Query 10: Facility Staffing Summary
-- ============================================================================
SELECT
  PROVNUM,
  PROVNAME,
  STATE,

  COUNT(*) AS reporting_days,

  ROUND(AVG(MDScensus), 2) AS avg_daily_census,

  ROUND(SUM(total_nursing_hours), 2) AS total_nursing_hours,

  ROUND(
    SAFE_DIVIDE(
      SUM(CASE
        WHEN MDScensus > 0 THEN total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN MDScensus > 0 THEN MDScensus
        ELSE 0
      END)
    ),
    2
  ) AS facility_HPRD,

  ROUND(
    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100,
    2
  ) AS contract_reliance_pct

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

GROUP BY
  PROVNUM,
  PROVNAME,
  STATE

ORDER BY
  facility_HPRD ASC;


-- ============================================================================
-- Query 11: Low Hprd Investigation
-- ============================================================================
WITH facility_summary AS (
  SELECT
    PROVNUM,
    PROVNAME,
    STATE,

    SAFE_DIVIDE(
      SUM(CASE
        WHEN MDScensus > 0 THEN total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN MDScensus > 0 THEN MDScensus
        ELSE 0
      END)
    ) AS facility_HPRD

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY
    PROVNUM,
    PROVNAME,
    STATE
),

low_hprd_facilities AS (
  SELECT
    PROVNUM
  FROM
    facility_summary
  WHERE facility_HPRD < 1
)

SELECT
  c.PROVNUM,
  c.PROVNAME,
  c.STATE,

  COUNT(*) AS reporting_days,

  ROUND(AVG(c.MDScensus), 2) AS avg_census,

  COUNTIF(c.MDScensus = 0) AS zero_census_days,

  COUNTIF(c.total_nursing_hours = 0) AS zero_staffing_days,

  ROUND(SUM(c.total_nursing_hours), 2) AS quarter_nursing_hours,

  ROUND(SUM(c.employee_nursing_hours), 2) AS employee_hours,

  ROUND(SUM(c.contract_nursing_hours), 2) AS contract_hours,

  ROUND(
    SAFE_DIVIDE(
      SUM(c.contract_nursing_hours),
      SUM(c.total_nursing_hours)
    ) * 100,
    2
  ) AS contract_reliance_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(CASE
        WHEN c.MDScensus > 0 THEN c.total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN c.MDScensus > 0 THEN c.MDScensus
        ELSE 0
      END)
    ),
    2
  ) AS facility_HPRD

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean` c

JOIN
  low_hprd_facilities l
ON
  c.PROVNUM = l.PROVNUM

GROUP BY
  c.PROVNUM,
  c.PROVNAME,
  c.STATE

ORDER BY
  facility_HPRD ASC;


-- ============================================================================
-- Query 12: Facility Size Staffing Comparison
-- ============================================================================
WITH facility_metrics AS (
  SELECT
    PROVNUM,
    PROVNAME,
    STATE,

    AVG(MDScensus) AS avg_daily_census,

    SAFE_DIVIDE(
      SUM(CASE
        WHEN MDScensus > 0 THEN total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN MDScensus > 0 THEN MDScensus
        ELSE 0
      END)
    ) AS facility_HPRD,

    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100 AS contract_reliance_pct

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY
    PROVNUM,
    PROVNAME,
    STATE
),

size_groups AS (
  SELECT
    *,

    CASE
      WHEN avg_daily_census < 50 THEN 'Small (<50)'
      WHEN avg_daily_census < 100 THEN 'Medium (50-99)'
      WHEN avg_daily_census < 150 THEN 'Large (100-149)'
      ELSE 'Very Large (150+)'
    END AS facility_size

  FROM facility_metrics
)

SELECT
  facility_size,

  COUNT(*) AS facility_count,

  ROUND(AVG(avg_daily_census), 2) AS avg_census,

  ROUND(AVG(facility_HPRD), 2) AS avg_HPRD,

  ROUND(
    APPROX_QUANTILES(facility_HPRD, 100)[OFFSET(50)],
    2
  ) AS median_HPRD,

  ROUND(AVG(contract_reliance_pct), 2)
    AS avg_contract_reliance_pct

FROM size_groups

GROUP BY facility_size

ORDER BY avg_census;


-- ============================================================================
-- Query 13: State Staffing Comparison
-- ============================================================================
SELECT
  STATE,

  COUNT(DISTINCT PROVNUM) AS facility_count,

  ROUND(
    SAFE_DIVIDE(
      SUM(CASE
        WHEN MDScensus > 0 THEN total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN MDScensus > 0 THEN MDScensus
        ELSE 0
      END)
    ),
    2
  ) AS state_HPRD,

  ROUND(
    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100,
    2
  ) AS contract_reliance_pct

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

GROUP BY
  STATE

ORDER BY
  state_HPRD DESC;


-- ============================================================================
-- Query 14: Contract Reliance Hprd Correlation
-- ============================================================================
WITH facility_metrics AS (
  SELECT
    PROVNUM,
    PROVNAME,
    STATE,

    SAFE_DIVIDE(
      SUM(CASE
        WHEN MDScensus > 0 THEN total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN MDScensus > 0 THEN MDScensus
        ELSE 0
      END)
    ) AS facility_HPRD,

    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100 AS contract_reliance_pct

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY
    PROVNUM,
    PROVNAME,
    STATE
)

SELECT
  COUNTIF(
    facility_HPRD IS NOT NULL
    AND contract_reliance_pct IS NOT NULL
  ) AS facilities_analyzed,

  ROUND(
    CORR(contract_reliance_pct, facility_HPRD),
    3
  ) AS contract_HPRD_correlation,

  ROUND(AVG(contract_reliance_pct), 2)
    AS avg_contract_reliance_pct,

  ROUND(AVG(facility_HPRD), 2)
    AS avg_HPRD

FROM facility_metrics

WHERE
  facility_HPRD IS NOT NULL
  AND contract_reliance_pct IS NOT NULL;


-- ============================================================================
-- Query 15: Nursing Skill Mix
-- ============================================================================
SELECT
  ROUND(SUM(Hrs_RN), 2) AS RN_hours,
  ROUND(SUM(Hrs_LPN), 2) AS LPN_hours,
  ROUND(SUM(Hrs_CNA), 2) AS CNA_hours,

  ROUND(SUM(total_nursing_hours), 2) AS total_nursing_hours,

  ROUND(
    SAFE_DIVIDE(
      SUM(Hrs_RN),
      SUM(total_nursing_hours)
    ) * 100,
    2
  ) AS RN_share_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(Hrs_LPN),
      SUM(total_nursing_hours)
    ) * 100,
    2
  ) AS LPN_share_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(Hrs_CNA),
      SUM(total_nursing_hours)
    ) * 100,
    2
  ) AS CNA_share_pct

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`;


-- ============================================================================
-- Query 16: Skill Mix By Facility Size
-- ============================================================================
WITH facility_metrics AS (
  SELECT
    PROVNUM,
    AVG(MDScensus) AS avg_daily_census,
    SUM(Hrs_RN) AS RN_hours,
    SUM(Hrs_LPN) AS LPN_hours,
    SUM(Hrs_CNA) AS CNA_hours,
    SUM(total_nursing_hours) AS total_nursing_hours

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY PROVNUM
),

size_groups AS (
  SELECT
    *,
    CASE
      WHEN avg_daily_census < 50 THEN 'Small (<50)'
      WHEN avg_daily_census < 100 THEN 'Medium (50-99)'
      WHEN avg_daily_census < 150 THEN 'Large (100-149)'
      ELSE 'Very Large (150+)'
    END AS facility_size

  FROM facility_metrics
)

SELECT
  facility_size,

  COUNT(*) AS facility_count,

  ROUND(
    SAFE_DIVIDE(SUM(RN_hours), SUM(total_nursing_hours)) * 100,
    2
  ) AS RN_share_pct,

  ROUND(
    SAFE_DIVIDE(SUM(LPN_hours), SUM(total_nursing_hours)) * 100,
    2
  ) AS LPN_share_pct,

  ROUND(
    SAFE_DIVIDE(SUM(CNA_hours), SUM(total_nursing_hours)) * 100,
    2
  ) AS CNA_share_pct

FROM size_groups

GROUP BY facility_size

ORDER BY
  CASE facility_size
    WHEN 'Small (<50)' THEN 1
    WHEN 'Medium (50-99)' THEN 2
    WHEN 'Large (100-149)' THEN 3
    WHEN 'Very Large (150+)' THEN 4
  END;


-- ============================================================================
-- Query 17: Contract Reliance By Role
-- ============================================================================
SELECT
  'RN' AS nursing_role,
  ROUND(SUM(Hrs_RN_emp), 2) AS employee_hours,
  ROUND(SUM(Hrs_RN_ctr), 2) AS contract_hours,
  ROUND(SUM(Hrs_RN), 2) AS total_hours,

  ROUND(
    SAFE_DIVIDE(
      SUM(Hrs_RN_ctr),
      SUM(Hrs_RN)
    ) * 100,
    2
  ) AS contract_reliance_pct

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

UNION ALL

SELECT
  'LPN',
  ROUND(SUM(Hrs_LPN_emp), 2),
  ROUND(SUM(Hrs_LPN_ctr), 2),
  ROUND(SUM(Hrs_LPN), 2),

  ROUND(
    SAFE_DIVIDE(
      SUM(Hrs_LPN_ctr),
      SUM(Hrs_LPN)
    ) * 100,
    2
  )

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

UNION ALL

SELECT
  'CNA',
  ROUND(SUM(Hrs_CNA_emp), 2),
  ROUND(SUM(Hrs_CNA_ctr), 2),
  ROUND(SUM(Hrs_CNA), 2),

  ROUND(
    SAFE_DIVIDE(
      SUM(Hrs_CNA_ctr),
      SUM(Hrs_CNA)
    ) * 100,
    2
  )

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`;


-- ============================================================================
-- Query 18: Contract Reliance Distribution
-- ============================================================================
WITH facility_contract AS (
  SELECT
    PROVNUM,

    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100 AS contract_reliance_pct

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY PROVNUM
)

SELECT
  COUNT(contract_reliance_pct) AS facilities_analyzed,

  ROUND(
    APPROX_QUANTILES(contract_reliance_pct, 100)[OFFSET(25)],
    2
  ) AS p25_contract_pct,

  ROUND(
    APPROX_QUANTILES(contract_reliance_pct, 100)[OFFSET(50)],
    2
  ) AS median_contract_pct,

  ROUND(
    APPROX_QUANTILES(contract_reliance_pct, 100)[OFFSET(75)],
    2
  ) AS p75_contract_pct,

  ROUND(
    APPROX_QUANTILES(contract_reliance_pct, 100)[OFFSET(90)],
    2
  ) AS p90_contract_pct,

  ROUND(
    APPROX_QUANTILES(contract_reliance_pct, 100)[OFFSET(95)],
    2
  ) AS p95_contract_pct,

  ROUND(
    APPROX_QUANTILES(contract_reliance_pct, 100)[OFFSET(99)],
    2
  ) AS p99_contract_pct,

  ROUND(MAX(contract_reliance_pct), 2)
    AS max_contract_pct

FROM facility_contract;


-- ============================================================================
-- Query 19: Contract Reliance Rn Share Correlation
-- ============================================================================
WITH facility_metrics AS (
  SELECT
    PROVNUM,

    SAFE_DIVIDE(
      SUM(Hrs_RN),
      SUM(total_nursing_hours)
    ) * 100 AS RN_share_pct,

    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100 AS contract_reliance_pct

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY PROVNUM
)

SELECT
  COUNT(*) AS facilities_analyzed,

  ROUND(
    CORR(contract_reliance_pct, RN_share_pct),
    3
  ) AS contract_RN_share_correlation,

  ROUND(AVG(RN_share_pct), 2)
    AS avg_RN_share_pct,

  ROUND(AVG(contract_reliance_pct), 2)
    AS avg_contract_reliance_pct

FROM facility_metrics

WHERE
  RN_share_pct IS NOT NULL
  AND contract_reliance_pct IS NOT NULL;


-- ============================================================================
-- Query 20: Facility Hprd Distribution
-- ============================================================================
WITH facility_metrics AS (
  SELECT
    PROVNUM,

    SAFE_DIVIDE(
      SUM(CASE
        WHEN MDScensus > 0 THEN total_nursing_hours
        ELSE 0
      END),
      SUM(CASE
        WHEN MDScensus > 0 THEN MDScensus
        ELSE 0
      END)
    ) AS facility_HPRD

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY PROVNUM
)

SELECT
  COUNT(facility_HPRD) AS facilities_analyzed,

  ROUND(
    APPROX_QUANTILES(facility_HPRD, 100)[OFFSET(25)],
    2
  ) AS p25_HPRD,

  ROUND(
    APPROX_QUANTILES(facility_HPRD, 100)[OFFSET(50)],
    2
  ) AS median_HPRD,

  ROUND(
    AVG(facility_HPRD),
    2
  ) AS avg_HPRD,

  ROUND(
    APPROX_QUANTILES(facility_HPRD, 100)[OFFSET(75)],
    2
  ) AS p75_HPRD,

  ROUND(
    APPROX_QUANTILES(facility_HPRD, 100)[OFFSET(90)],
    2
  ) AS p90_HPRD,

  ROUND(
    APPROX_QUANTILES(facility_HPRD, 100)[OFFSET(95)],
    2
  ) AS p95_HPRD,

  ROUND(
    MIN(facility_HPRD),
    2
  ) AS min_HPRD,

  ROUND(
    MAX(facility_HPRD),
    2
  ) AS max_HPRD

FROM facility_metrics;


-- ============================================================================
-- Query 21: Census Staffing Correlation
-- ============================================================================
WITH facility_metrics AS (
  SELECT
    PROVNUM,

    AVG(MDScensus) AS avg_daily_census,

    AVG(total_nursing_hours) AS avg_daily_nursing_hours

  FROM
    `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

  GROUP BY
    PROVNUM
)

SELECT
  COUNT(*) AS facilities_analyzed,

  ROUND(
    CORR(avg_daily_census, avg_daily_nursing_hours),
    3
  ) AS census_staffing_correlation,

  ROUND(AVG(avg_daily_census), 2)
    AS avg_facility_census,

  ROUND(AVG(avg_daily_nursing_hours), 2)
    AS avg_daily_nursing_hours

FROM facility_metrics

WHERE
  avg_daily_census IS NOT NULL
  AND avg_daily_nursing_hours IS NOT NULL;


-- ============================================================================
-- Query 22: Monthly Contract Reliance
-- ============================================================================
SELECT
  FORMAT_DATE(
    '%Y-%m',
    PARSE_DATE('%Y%m%d', WorkDate)
  ) AS month,

  ROUND(
    SUM(contract_nursing_hours),
    2
  ) AS contract_nursing_hours,

  ROUND(
    SUM(total_nursing_hours),
    2
  ) AS total_nursing_hours,

  ROUND(
    SAFE_DIVIDE(
      SUM(contract_nursing_hours),
      SUM(total_nursing_hours)
    ) * 100,
    2
  ) AS contract_reliance_pct

FROM
  `projectblue-500000.healthcare_workforce_analysis.pbj_daily_nurse_staffing_clean`

GROUP BY month

ORDER BY month;
