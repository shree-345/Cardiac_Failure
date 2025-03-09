--1_Show yearly count of patients as a outcome classification
---ALIVE, DEAD, DISCHARGE AGAINT ORDER during hospitalization process
--QUERY:	
	CREATE EXTENSION IF NOT EXISTS tablefunc;
SELECT * FROM pg_extension;
SELECT * FROM crosstab
	($$
	SELECT EXTRACT(YEAR FROM admission_date),outcome_during_hospitalization,
	COUNT(inpatient_number)
FROM hospitalization_discharge 
GROUP BY 1,2
ORDER BY 1,2
	$$)
AS ct(Admission_Year numeric, Alive bigint, Dead bigint, DischargeAgainstOrder bigint);
--This query will help us to analyze the yearly mortality rate.
--Output Screenshot:

--2) Write a query to display which gender has MAX cci_score under each age category
--Corrosponding to each record)
--QUERY:	
SELECT agecat,gender,cci_score, first_value (gender) OVER(PARTITION BY agecat ORDER BY cci_score DESC) 
	as gender_with_max_cci_score FROM demography d
	JOIN patienthistory p ON p.inpatient_number = d.inpatient_number

--3) Write a query to display 5th highest BMI in demography table 
--QUERY:	
SELECT DISTINCT NTH_VALUE(bmi,5)OVER(ORDER BY bmi DESC)
as fifth_highest_bmi FROM demography
	WHERE bmi IS NOT NULL;

--4) Write a query to segregate patients BMI in  4 equal-sized Bucket
--QUERY:	
SELECT inpatient_number,bmi, NTILE(4)OVER(ORDER BY bmi DESC) AS bmi_quartile
 FROM demography


--5) Calculate the cumulative distribution of blood sugar levels for patients diagnosed with Diabetes
--QUERY:	

SELECT labs.inpatient_number,
	glucose_blood_gas, CUME_DIST()OVER (ORDER BY glucose_blood_gas ASC) AS cum_dist
	FROM labs JOIN patienthistory p ON p.inpatient_number = labs.inpatient_number
WHERE diabetes = 1 AND glucose_blood_gas IS NOT NULL
ORDER BY 2


--6) Display mean, Interquartile range, 2 standard deviations above mean, and 2 standard deviations below mean of any one systolic Blood pressure for all patients in the database grouped by age category
--QUERY:
SELECT agecat AS Age_Catogory,
          	ROUND(AVG(systolic_blood_pressure),1) AS MEAN ,
          	ROUND(STDDEV(systolic_blood_pressure),1) AS STDDEV ,
          	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY systolic_blood_pressure) -
          	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY systolic_blood_pressure) AS IQR ,
          	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY systolic_blood_pressure) AS Q3_2STDABOVEMEAN_ ,
          	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY systolic_blood_pressure) AS Q1_2STDBELOWMEAN
FROM labs l
JOIN demography d ON l.inpatient_number = d.inpatient_number
GROUP BY 1;
--This query provides a detailed statistical breakdown of systolic blood pressure across different age categories, giving us a comprehensive view of the data distribution




--7)Concatenate agecat, respiratory_support and patient ID with a ';' in between and 'n/a' in place of null
--Query
select concat(d.inpatient_number,';',agecat,';',coalesce(respiratory_support,'n/a')) from public.demography d
join public.hospitalization_discharge hd on d.inpatient_number = hd.inpatient_number

--8)What type of drug is prescibed for patients who had diabetes history and age above 50.
--Query
select count(d.inpatient_number) as totalpatients,drug_name  from public.demography d
right outer join public.patienthistory ph on d.inpatient_number = ph.inpatient_number 
left outer join public.patient_precriptions pp on ph.inpatient_number = pp.inpatient_number
where age>50 and diabetes =1
group by drug_name



--9)Which agecat were common among those with a death in 6 months
--Query
select count(hd.inpatient_number) as frequency_of_patientsindeath_in6months, agecat from public.demography d
join public.hospitalization_discharge hd on d.inpatient_number = hd.inpatient_number
where death_within_6_months =1
group by agecat
order by frequency_of_patientsindeath_in6months desc
limit 1


--10) How many patients in this dataset are Urbanresident?
--Query:

SELECT occupation, COUNT(*)  as Total_Patients FROM demography
WHERE occupation = 'UrbanResident'
GROUP BY occupation


--11) what was the average time to readmission among female
--Query:
SELECT gender, Concat(CAST(AVG(readmission_time_days_from_admission) AS INT),' days')
	as Avg_readmission_days FROM hospitalization_discharge h
	JOIN demography d ON d.inpatient_number = h.inpatient_number
	WHERE gender = 'Female'
	GROUP BY 1



--12.-What is the average height of men in cms? 
--Query:

SELECT gender, CONCAT(CAST((AVG(height))*100 AS INT),'cm') as Avg_Height FROM demography
WHERE gender = 'Male'
GROUP BY 1


----13. Display highest prescribed drug name in the month of Oct 2018 admitted patients
--Query:

SELECT 
    p.drug_name,
    COUNT(*) AS prescription_count
FROM 
    hospitalization_discharge h
JOIN patient_precriptions p ON h.inpatient_number = p.inpatient_number
WHERE 
    h.admission_date >= '2018-10-01' AND 
    h.admission_date < '2018-11-01'
GROUP BY 
    p.drug_name
ORDER BY 
    prescription_count DESC
LIMIT 1;


--14. Find the Percentage of Heart Failure Patients with Diabetes by Age Group

--Query:

SELECT
    d.ageCat,
    COUNT(CASE WHEN ph.diabetes = 1 THEN 1 ELSE NULL END) AS DiabeticHeartFailurePatients,
    COUNT(*) AS TotalHeartFailurePatients,
    (COUNT(CASE WHEN ph.diabetes = 1 THEN 1 ELSE NULL END) * 100.0 / COUNT(*)) AS PercentageDiabetic
FROM
    Demography d
    JOIN patienthistory ph ON d.inpatient_number = ph.inpatient_number
    JOIN cardiaccomplications cc ON d.inpatient_number = cc.inpatient_number
GROUP BY d.ageCat
ORDER BY PercentageDiabetic DESC;


--15. Find the Readmission count and Mortality, by Type of Heart Failure and Kidney Disease

---Query:

SELECT
    cc.type_of_heart_failure,
    ph.moderate_to_severe_chronic_kidney_disease,
    SUM(CASE WHEN hd.re_admission_within_6_months = 1 THEN 1 ELSE 0 END) AS ReadmissionCount,
    SUM(CASE WHEN hd.death_within_6_months = 1 THEN 1 ELSE 0 END) AS DeathCount
FROM
    cardiaccomplications cc
    JOIN patienthistory ph ON cc.inpatient_number = ph.inpatient_number
    JOIN hospitalization_discharge hd ON cc.inpatient_number = hd.inpatient_number
GROUP BY cc.type_of_heart_failure, ph.moderate_to_severe_chronic_kidney_disease
ORDER BY ReadmissionCount DESC, DeathCount DESC;



--16. Find the number of patients readmitted within 6 months by Killip grade and type of heart failure.

--Query:

SELECT c.Killip_grade, c.type_of_heart_failure, COUNT(h.re_admission_within_6_months) AS readmission_count
FROM cardiaccomplications c
JOIN hospitalization_discharge h ON c.inpatient_number = h.inpatient_number
WHERE h.re_admission_within_6_months = 1
GROUP BY c.Killip_grade, c.type_of_heart_failure
ORDER BY readmission_count DESC;


--17. List patients who had myocardial infarction and show the difference between their systolic and diastolic blood pressure.

--Query:

SELECT l.inpatient_number, l.systolic_blood_pressure, l.diastolic_blood_pressure,
       (l.systolic_blood_pressure - l.diastolic_blood_pressure) AS pressure_difference
FROM labs l
JOIN cardiaccomplications c ON l.inpatient_number = c.inpatient_number
WHERE c.myocardial_infarction = 1;


--18.  Calculate the maximum, minimum, and average uric acid levels for patients who had a myocardial infarction.

--Query:

SELECT MAX(l.uric_acid) AS max_uric_acid, MIN(l.uric_acid) AS min_uric_acid, AVG(l.uric_acid) AS avg_uric_acid
FROM labs l
JOIN cardiaccomplications c ON l.inpatient_number = c.inpatient_number
WHERE c.myocardial_infarction = 1;



--19. Compare the mortality rate within 28 days for patients with NYHA classification greater than 3.

--Query:

SELECT c.NYHA_cardiac_function_classification, 
       (COUNT(*) FILTER (WHERE h.death_within_28_days = 1) * 100.0 / COUNT(*)) AS mortality_rate
FROM cardiaccomplications c
JOIN hospitalization_discharge h ON c.inpatient_number = h.inpatient_number
WHERE c.NYHA_cardiac_function_classification > 3
GROUP BY c.NYHA_cardiac_function_classification;

--20.  Find the Cumulative Sum of Admissions Over the years available in the dataset


--Query:


SELECT admission_date, COUNT(*) AS daily_admissions, 
       SUM(COUNT(*)) OVER (ORDER BY admission_date) AS cumulative_admissions
FROM hospitalization_discharge
GROUP BY admission_date
ORDER BY admission_date;

--21. Calculate the average systolic and diastolic blood pressure for each age category.

--Query:

SELECT d.ageCat, 
       AVG(l.systolic_blood_pressure) AS avg_systolic_bp, 
       AVG(l.diastolic_blood_pressure) AS avg_diastolic_bp
FROM Demography d
JOIN labs l ON d.inpatient_number = l.inpatient_number
GROUP BY d.ageCat;

--22. Calculate the Percentage of Heart Failure by Age Category
--Query:

WITH total_patients AS (
    SELECT ageCat, COUNT(*) AS total
    FROM Demography
    GROUP BY ageCat
), heart_failure_patients AS (
    SELECT d.ageCat, COUNT(*) AS heart_failure_count
    FROM Demography d
    JOIN cardiaccomplications cc ON d.inpatient_number = cc.inpatient_number
    WHERE cc.congestive_heart_failure = 1
    GROUP BY d.ageCat
)
SELECT tp.ageCat, 
       hf.heart_failure_count, 
       (hf.heart_failure_count::decimal / tp.total) * 100 AS percentage
FROM total_patients tp
LEFT JOIN heart_failure_patients hf ON tp.ageCat = hf.ageCat;


--23.  Find patients with both high blood pressure (systolic > 140 mmHg or diastolic > 90 mmHg) 
--and abnormal left ventricular function (LVEF < 50%).--Query:

--Query:

SELECT d.inpatient_number, l.systolic_blood_pressure, l.diastolic_blood_pressure, cc.LVEF
FROM Demography d
JOIN labs l ON d.inpatient_number = l.inpatient_number
JOIN cardiaccomplications cc ON d.inpatient_number = cc.inpatient_number
WHERE (l.systolic_blood_pressure > 140 OR l.diastolic_blood_pressure > 90)
AND cc.LVEF < 50;


--24. Calculate the percentage of patients who were readmitted and compare it with those who died within 6 months of discharge.

--Query:

re_admissions AS (
    SELECT COUNT(*) AS re_admission_count 
    FROM hospitalization_discharge 
    WHERE re_admission_within_6_months = 1
),
deaths AS (
    SELECT COUNT(*) AS death_count 
    FROM hospitalization_discharge 
    WHERE death_within_6_months = 1
)
SELECT 
    (ra.re_admission_count::decimal / tp.total) * 100 AS re_admission_percentage,
    (d.death_count::decimal / tp.total) * 100 AS death_percentage
FROM total_patients tp, re_admissions ra, deaths d;

--25. Analyze the number of hospital admissions by quarter.

--Query:

SELECT 
    EXTRACT(QUARTER FROM admission_date) AS quarter,
    COUNT(*) AS admissions_count
FROM hospitalization_discharge
GROUP BY quarter
ORDER BY quarter;
