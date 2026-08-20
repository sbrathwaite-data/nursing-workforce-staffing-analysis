# Nursing Workforce & Staffing Analysis

## Project Overview

This project analyzes Q1 2026 CMS Payroll-Based Journal (PBJ) Daily Nurse Staffing data to examine how nursing staffing capacity aligns with resident demand across U.S. long-term-care facilities.

## Business Question

**How effectively are long-term-care facilities aligning nursing staffing capacity with resident demand, and where are potential staffing pressures occurring?**

## Tools

- Google Sheets
- SQL / BigQuery
- Tableau Public

## Dataset

- **Source:** CMS Payroll-Based Journal (PBJ) Daily Nurse Staffing
- **Period:** Q1 2026
- **Facilities:** 14,487
- **Records analyzed:** 1,303,830

## Key Findings

- Staffing scaled strongly with resident demand (**r = 0.925**), although HPRD varied across facilities and facility sizes.
- **29 facilities** reported HPRD below 1.0, representing potential staffing or reporting signals requiring further review.
- Nursing hours consisted primarily of **CNA hours (63.62%)**, followed by LPN (23.25%) and RN (13.13%).
- Contract reliance varied substantially across facilities and locations but remained stable throughout Q1 at approximately **5.76–5.78%**.

## Recommendations

- Review facilities with extreme HPRD values to identify potential staffing pressures or reporting issues.
- Compare staffing patterns among facilities of similar size and resident census.
- Investigate facilities and locations with unusually high contract reliance, particularly for licensed nursing roles.

## Data Validation

Staffing components were validated across all **1,303,830 records with 0 mismatches**. Unusual observations were investigated rather than automatically removed.

## Dashboard

**[View the interactive Tableau dashboard](https://public.tableau.com/views/NursingWorkforceStaffingAnalysis/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

## Project Files

- SQL analysis
- Results summary
- Findings & interpretation
- Cleaned analytical data
