---1. Update the demography table. Add a random age for each patient that falls within their respective age category. This newly added age should be an integer.	
--QUERY:
SELECT * FROM demography
ALTER TABLE demography
ADD COLUMN age int;
UPDATE demography
SET age = CASE
	WHEN agecat = '21-29' THEN
FLOOR(21 +RANDOM()* 10)
    WHEN agecat = '29-39' THEN
FLOOR(29 +RANDOM()* 11)
    WHEN agecat = '39-49' THEN
FLOOR(39 +RANDOM()* 11)
   WHEN agecat = '49-59' THEN
FLOOR(49 +RANDOM()* 11)
   WHEN agecat = '59-69' THEN
FLOOR(59 +RANDOM()* 11)
   WHEN agecat = '69-79' THEN
FLOOR(69 +RANDOM()* 11)
    WHEN agecat = '79-89' THEN
FLOOR(79 +RANDOM()* 11)
     WHEN agecat = '89-110' THEN
FLOOR(89 +RANDOM()* 21)
    ELSE age
END;

--2. Calculate patient's year of birth using admission date from the hospitalization_discharge and add to the demography table.
--QUERY:
ALTER TABLE demography
	ADD COLUMN birth_year INT;
WITH Y AS(
WITH CTE AS(
	SELECT inpatient_number, EXTRACT(YEAR FROM admission_date)AS  years FROM hospitalization_discharge 
)
  SELECT d.inpatient_number, (years - age) as y FROM CTE
     JOIN demography d ON d.inpatient_number = CTE.inpatient_number)
	
UPDATE  demography
SET birth_year = Y.y FROM Y
WHERE demography.inpatient_number = Y.inpatient_number

--3. Create a User defined function that returns the age in years of any patient as a calculation from year of birth 
--QUERY:	
CREATE OR REPLACE FUNCTION fn_current_age
	 (
     CurrentDate date,
     BirthYear int)
	 returns int
    As
	$$
    Begin 
	return (Select (EXTRACT(YEAR FROM CurrentDate) - BirthYear));
    End
	$$
   language plpgsql;
Select fn_current_age(Current_date,birth_year) as Present_Age, * from demography
--4. What % of the dataset is male vs female?
--QUERY:	

WITH CTE AS(
	SELECT COUNT(*) FROM demography	
)
	
SELECT gender, COUNT(*) as total_count,
	CONCAT(((COUNT(*) * 100)/(SELECT * FROM CTE)), '%') as percentage_count FROM demography
	WHERE gender IS NOT NULL
GROUP BY gender

--5. How many patients in this dataset are farmers?
--QUERY:	

SELECT occupation, COUNT(*)  as Total_Patients FROM demography
WHERE occupation = 'farmer'
GROUP BY occupation


--6) Group the patients by age category and display it as a pie chart
--QUERY:	

\set width 80
\set height 25
\set radius 1.0
\set colours '''#;o:X"@+-=123456789abcdef'''
WITH slices AS (
SELECT CAST(
row_number() over () AS integer) AS slice,name,value,100.0 * value/
sum(value) OVER () AS percentage,
2*PI()*  sum(value) OVER (rows unbounded preceding)/ sum(value) OVER ()
AS radians FROM
(select agecat as AgeCatogory,
count (*) as TotalPatients FROM demography
Where agecat is not null
group by 1)
AS data(name,value))
(SELECT array_to_string(array_agg(c),’’) AS pie_chart
FROM (SELECT x, y,
CASE WHEN NOT (sqrt(pow(x, 2) + pow(y, 2)) BETWEEN 0.0 AND :radius)
THEN ' '
ELSE substring(:colours,
(select min(slice) from slices where radians >= PI() + atan2(y,-x)), 1)
END AS c
FROM(SELECT 2.0*generate_series(0,:width)/:width-1.0) AS x(x),
(SELECT 2.0*generate_series(0,:height)/:height-1.0) AS y(y)
ORDER BY y,x) AS xy
GROUP BY y
ORDER BY y
)
UNION ALL
SELECT repeat(substring(:colours,slice,1), 2) || ' ' ||
name || ' : ' ||
value || ' : ' ||
round(percentage,0) || '%'
FROM slices;

--7. Divide BMI into slabs of 5 and show the count of patients within each one,without using case statements.
--QUERY:	
--(BMI ranges divided in to 5 slab with min of 0 and max of 50 value. slab 1 means bmi 1-10 and so on)
SELECT width_bucket (bmi, 0,50,5) as BMI_Ranges, COUNT(*) as Patients_counts from demography
WHERE BMI <> 0 AND BMI<50 --(removing some outlier from dataset)
GROUP BY 1
--8. What % of the dataset is over 70 years old
--QUERY:
	SELECT concat(((COUNT(*)*100)/ (SELECT COUNT(*) from demography)),'%')
	as patients_over_70 from demography
	WHERE age >70
	
--9. What age group was least likely to be readmitted within 28 days
--QUERY:	
	SELECT agecat, COUNT(re_admission_within_28_days) FROM hospitalization_discharge h
	JOIN demography d ON h.inpatient_number = h.inpatient_number
	WHERE re_admission_within_28_days = 0 AND agecat IS NOT NULL
	GROUP BY 1
	ORDER BY 2 DESC
	LIMIT 1
--10. Create a procedure to insert a column with a serial number for all rows in demography.
--QUERY:	
ALTER TABLE demography 
ADD COLUMN Serial_number INT;

 CREATE OR REPLACE PROCEDURE update_serial_number()
	LANGUAGE plpgsql
	AS
	$$
	BEGIN
	UPDATE demography
	 SET serial_number = rows FROM
	 (SELECT inpatient_number, row_number() OVER
	 (ORDER BY 1)AS rows
	 FROM demography) AS subquery
	 WHERE demography.inpatient_number = subquery.inpatient_number;
	END;
	 $$;
   
CALL update_serial_number();
SELECT * FROM demography
WHERE serial_number IS NOT NULL


--11. what was the average time to readmission among men
--QUERY:	
    SELECT gender, Concat(CAST(AVG(readmission_time_days_from_admission) AS INT),' days')
	as Avg_readmission_days FROM hospitalization_discharge h
	JOIN demography d ON h.inpatient_number = h.inpatient_number
	WHERE gender = 'Male'
	GROUP BY 1
--12. Display NYHA_cardiac_function_classification as Class I: No symptoms of heart failure
 Class II: Symptoms of heart failure with moderate exertion
 Class III: Symptoms of heart failure with minimal exertion 
and show the most common type of heart failure for each classification"

	/*In the New York Heart Association (NYHA) cardiac function classification
	number 2 represents a slight limitation in physical activity with symptoms like shortness of breath occurring during ordinary activities,
number 3 indicates a marked limitation where even minimal activity causes symptoms,
and number 4 signifies severe limitations with symptoms present even at rest,
essentially unable to carry out any physical activity without discomfort */
--QUERY:	
SELECT 
	CASE 
	WHEN nyha_cardiac_function_classification = 2 THEN 'Class I: No symptoms of heart failure'
	WHEN nyha_cardiac_function_classification=  3 THEN 'Class II: Symptoms of heart failure with moderate exertion'
	WHEN  nyha_cardiac_function_classification= 4 THEN 'Class III: Symptoms of heart failure with minimal exertion' END AS  NYHA_cardiac_function_Class,
 type_of_heart_failure,COUNT(*)FROM cardiaccomplications
GROUP BY 1,2
ORDER BY 1,3

--13. Identify any columns relating to echocardiography
--and create a severity score for cardiac function. Add this column to the table
--QUERY:	

SELECT killip_grade, COUNT(*) FROM cardiaccomplications
GROUP BY 1---run here
ALTER TABLE cardiaccomplications 
ADD COLUMN killip_grade_severity_score VARCHAR(200);---run here
UPDATE cardiaccomplications 
	 SET killip_grade_severity_score = KG_class FROM
	 (SELECT inpatient_number, CASE 
WHEN killip_grade = 1 THEN 'Class I: No signs of congestion'
WHEN  killip_grade = 2 THEN 'Class II: S3 and basal rales on auscultation'
WHEN  killip_grade = 3 THEN 'Class III: Acute pulmonary oedema'
WHEN killip_grade = 4 THEN 'Class IV: Cardiogenic shock' END
AS KG_class
	 FROM cardiaccomplications) AS subquery
	 WHERE cardiaccomplications.inpatient_number = subquery.inpatient_number;--run here

SELECT killip_grade, killip_grade_severity_score FROM  cardiaccomplications---run here

--14. What is the average height of women in cms?
--QUERY:	
SELECT gender, CONCAT(CAST((AVG(height))*100 AS INT),' cm') as Avg_Height FROM demography
WHERE gender ='Female'
GROUP BY 1
--15. Using the cardiac severity column from q13,
--find the correlation between hospital outcomes and cardiac severity
--QUERY:	
SELECT corr(killip_grade, dischargeday) as correlation_value FROM hospitalization_discharge h
JOIN cardiaccomplications c ON c.inpatient_number = h.inpatient_number

--16. Show the no. of patients for everyday in March 2017.
--Show the date in March along with the days between the previous recorded day in march and the current.
--QUERY:	
SELECT admission_date :: DATE as March_2017_admission, LAG(admission_date :: DATE) OVER(ORDER BY admission_date)
AS previous_date,((admission_date :: DATE) -  LAG(admission_date :: DATE) OVER(ORDER BY admission_date))
AS day_between, COUNT(inpatient_number) OVER() as Total_Patients FROM hospitalization_discharge
WHERE admission_date  BETWEEN '2017-03-01' AND '2017-03-31'

--17.Create a view that combines patient demographic  details of your choice along with pre-exisiting heart conditions like MI,CHF and PVD

--QUERY:	
CREATE VIEW patient_demographic_details_view AS
select d.inpatient_number, d.gender, d.height, d.weight,
c.myocardial_infarction, c.peripheral_vascular_disease, c.congestive_heart_failure from demography as d
right join cardiaccomplications as c ON d.inpatient_number = c.inpatient_number--- run here

select * from patient_demographic_details_view-- run here
-- drop view patient_demographic_details_view

 --18.Create a function to calculate total number of unique patients for every drug.
--Results must be returned as long as the first few characters match the user input.
--QUERY:	
CREATE OR REPLACE FUNCTION get_unique_patients_per_drug(partial_drug_name VARCHAR)
RETURNS TABLE (drug_drug TEXT, unique_patient_count bigint) AS $$
BEGIN
    RETURN QUERY
SELECT
drug_name,
COUNT(DISTINCT inpatient_number) AS unique_patient_count
    FROM
        patient_precriptions
where drug_name ILIKE partial_drug_name || '%'
    GROUP BY
        drug_name;
END; $$
LANGUAGE 'plpgsql';

select * from patient_precriptions;
select * from get_unique_patients_per_drug('Hydrochloroth')
---19.break up the drug names in patient_precriptions at the ""spaces"" and display only the second string without using Substring. Show unique drug names along with newly broken up string
--QUERY:	
SELECT DISTINCT
    drug_name,
    SPLIT_PART(drug_name, ' ', 2) AS second_word
FROM patient_precriptions
WHERE SPLIT_PART(drug_name, ' ', 2) IS NOT NULL;


--20.Select the drug names starting with E and has x in any position after
--QUERY:
select drug_name from patient_precriptions where drug_name LIKE 'E%x%'

--21.Create a cross tab to show the count of readmissions within  28 days, 3 months,6 months as rows and admission ward as columns
--QUERY:
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Crosstab query
SELECT time_frame,
    COALESCE("Cardiology", 0) AS "Cardiology",
	COALESCE("GeneralWard", 0) AS "GeneralWard",
	COALESCE("ICU" ,0) AS "ICU",
	COALESCE("Others", 0) AS "Others"

	FROM crosstab(
    $$
    SELECT time_frame, admission_ward, patient_count
    FROM (
        SELECT admission_ward, '28Days' AS time_frame, COUNT(*) AS patient_count
        FROM hospitalization_discharge
        WHERE re_admission_within_28_days = 1
        GROUP BY admission_ward
        UNION
        SELECT admission_ward, '90Days' AS time_frame, COUNT(*) AS patient_count
        FROM hospitalization_discharge
        WHERE re_admission_within_3_months = 1
        GROUP BY admission_ward
        UNION
        SELECT admission_ward, '180Days' AS time_frame, COUNT(*) AS patient_count
        FROM hospitalization_discharge
        WHERE re_admission_within_6_months = 1
        GROUP BY admission_ward
		UNION
		SELECT admission_ward, 'DWithin6monthhs' AS time_frame, COUNT(*) AS patient_count
        FROM hospitalization_discharge
        WHERE death_within_6_months = 1
        GROUP BY admission_ward
    ) AS subquery
    ORDER BY time_frame
    $$,
    $$ 
    SELECT DISTINCT admission_ward FROM hospitalization_discharge ORDER BY admission_ward
    $$ 
) AS ct (time_frame TEXT, "Cardiology" NUMERIC, "GeneralWard" NUMERIC, "ICU" NUMERIC, "Others" NUMERIC);

--22.Create a trigger to stop patient records from being deleted from the demography table
--QUERY:


CREATE OR REPLACE FUNCTION stop_patient_deletion() 
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Patient records delete is not allowed.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stop_patient_deletion_trigger
BEFORE DELETE ON demography
FOR EACH ROW EXECUTE FUNCTION stop_patient_deletion();

--23.What is the total number of days between the earliest admission and the latest
--QUERY:
SELECT
    EXTRACT(DAY FROM (MAX(admission_date) - MIN(admission_date))) AS total_days
FROM hospitalization_discharge;
--24. Divide discharge day by visit times for any 10 patients without using mathematical operators like '/'
--QUERY:


with hospitalization_data as (
SELECT 
    inpatient_number,
    dischargeday,
    visit_times
	from 
	hospitalization_discharge
	where
   	dischargeday is not null and
    visit_times is not null
	limit 10
)
	SELECT 
    inpatient_number,
    dischargeday,
    visit_times,
case
	 when visit_times = 0 then null
	 else dischargeday -
	 (case 
	 when dischargeday>=visit_times then visit_times
	 else dischargeday  end )
	 end as discharge_per_visit
	 from hospitalization_data;
	
--25. Show the count of patients by first letter of admission_way.
--QUERY:

SELECT
    LEFT(admission_way, 1) AS first_letter,
    COUNT(*) AS patient_count
FROM
    hospitalization_discharge
GROUP BY
    first_letter
ORDER BY
    first_letter;

--26. Display an array of personal markers:gender, BMI, pulse, MAP for every patient. The result should look like this
--QUERY:

SELECT 
    d.inpatient_number,
    ARRAY_AGG(ROW(d.gender, d.bmi, l.map_value, l.pulse)) AS markers
FROM 
    demography d
JOIN labs l 
ON d.inpatient_number = l.inpatient_number
group by d.inpatient_number

--27. Display medications With Name contains 'hydro' and display it as 'H20'.

--QUERY:
select drug_name as "H20"
 from patient_precriptions where drug_name ilike '%hydro%' ;
 
 --28. Create a trigger to raise notice and prevent deletion of the view created in question 17
--QUERY:  
CREATE OR REPLACE FUNCTION patient_demographic_view_drop()
RETURNS event_trigger AS $$
BEGIN
    RAISE EXCEPTION 'patient_demographic_view drop is not allowed.';
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER patient_demographic_view_drop_trigger
ON ddl_command_start
WHEN TAG IN ('DROP VIEW')
EXECUTE FUNCTION patient_demographic_view_drop();

drop view patient_demographic_details_view

--29. How many unique patients have cancer?

--QUERY:  
SELECT COUNT(DISTINCT inpatient_number) AS unique_cancer_patients
FROM patienthistory
WHERE solid_tumor=1

--30. Show the moving average of number of patient admitted every 3 months.
--QUERY:
WITH total_monthly_admissions AS (
    SELECT
        date_trunc('month', admission_date) AS admission_month,
        COUNT(inpatient_number) AS patient_count
    FROM
        hospitalization_discharge
    GROUP BY
        admission_month
)
SELECT
    admission_month,
    patient_count,
    AVG(patient_count) OVER (
        ORDER BY admission_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_average_3_months
FROM
    total_monthly_admissions
ORDER BY
    admission_month;

--31. Write a query to get a list of patient IDs' who recieved oxygen therapy and had a high respiration rate in February 2017

--QUERY:


SELECT inpatient_number, respiratory_support
FROM hospitalization_discharge
WHERE oxygen_inhalation = 'OxygenTherapy'
  AND respiratory_support != 'null'
  AND admission_date >= '2017-02-01'
  AND admission_date < '2017-03-01';
  
 --32. Display patients with heart failure type: "both" along with highest MAP and higest pulse without using limit

--QUERY:

SELECT 
    c.inpatient_number,
    c.type_of_heart_failure,
    MAX(l.map_value) AS highest_map,
    MAX(l.pulse) AS highest_pulse
FROM 
    cardiaccomplications c
JOIN 
    labs l ON c.inpatient_number = l.inpatient_number
WHERE 
    c.type_of_heart_failure = 'Both'
GROUP BY 
    c.inpatient_number, c.type_of_heart_failure;

--33. Create a stored procedure that displays any message on the screen without using any tables/views.
--QUERY:
create procedure raise_notice (s text) language plpgsql as 
$$
begin 
    raise notice '%', s;
end;
$$;
call raise_notice('Happy Coding');

---34. In healthy people, monocytes make up about 1%-9% of total white blood cells. Calculate avg monocyte percentages among each age group.
--QUERY:
select agecat , round((avg(monocyte_percentage)*100),2)  as average_monocyte_percentage
from (
select  agecat , (monocyte_count::numeric /nullif(count(white_blood_cell),0)) as monocyte_percentage 	
from public.demography d join public.labs l 
on d.inpatient_number = l.inpatient_number 
group by agecat , monocyte_count
     ) 
group by agecat	
order by agecat	;

--35. Create a table that stores any Patient Demographics of your choice as the parent table. 
	--Create a child table that contains systolic_blood_pressure,diastolic_blood_pressure 
--per patient and inherits all columns from the parent table
--QUERY:
create table patient_history (
	inpatient_number bigint,
	gender           text,
	agecat           text
);
insert into patient_history (inpatient_number, gender, agecat)
values  (827040, 'Female', '69-79'),
        (857781, 'Female', '69-79'),
        (743087,  'Male',  '69-79'),
         (866418,  'Male',  '59-69'),
        (775928, 'Female', '69-79'),
        (810128,  'Male',  '69-79'),
        (823318,  'Male',  '79-89'),
        (844094, 'Female', '79-89'),
        (787530, 'Female', '69-79');

create table patient_labs ( 
	systolic_blood_pressure bigint,
	diastolic_blood_pressure bigint
) inherits (patient_history);

insert into patient_labs (systolic_blood_pressure, diastolic_blood_pressure)
values   (102 , 64),
             (150 , 70),	
             (102 , 67),
             (110 , 74),
             (134 , 62),
             (96  , 64),
             (129 , 54),
             (112 , 60),
             (166 , 85);

--36. Write a select statement with no table or view attached to it 
--QUERY:
select generate_series(1,10)

--37. Create a re-usable function to calculate the percentage of patients for any group.
--Use this function to calculate % of patients in each admission ward."

--QUERY:
CREATE OR REPLACE FUNCTION patients_percentage_calculation
	 (group_column text)
	 returns table(
    
	group_value TEXT,
    patient_count BIGINT,
    percentage NUMERIC)
	AS $$
    Begin 
	RETURN QUERY EXECUTE format(
	'Select %I AS group_value, COUNT(*) AS patient_count, ROUND((COUNT(*)*100/
	(SELECT COUNT(*)  FROM hospitalization_discharge)),2) AS percentage
	FROM hospitalization_discharge
	GROUP BY %I',
	group_column, group_column);
end;
$$ LANGUAGE plpgsql;  --run here
SELECT * FROM patients_percentage_calculation('admission_ward');


--38. Write a query that shows if CCI score is an even or odd number for any 10 patients	

--QUERY:
SELECT cci_score,  inpatient_number,
CASE
  WHEN (cci_score::int % 2) = 0 THEN 'Even'
 ELSE 'odd'
END AS "Score_Odd_Even"
FROM patienthistory
where inpatient_number in (857781,748109,814592,828763,738813,729332,815585,780166,743467,764380);
--39. Using windows functions show the number of hospitalizations in the previous month and the next month

--QUERY:
with hospitalizations as (	
select  date_trunc('month',admission_date) as month,
count(*) as hospitalization_count
	from public.hospitalization_discharge
	group by month
)
select 
	month,
	hospitalization_count,
	lag(hospitalization_count)over (order by month)as previous_month,	lead(hospitalization_count)over (order by month)as next_month	from hospitalizations
order by month ;

--40. Write a function to get comma-separated values of patient details based on patient number entered by the user. 
	(Use a maximum of 6 columns from different tables)

--QUERY:
create function patient_details_csv(patient_number bigint)	
returns text as $$
declare 
	patient_details text;
begin
	SELECT string_agg( d.inpatient_number ||':' || gender ||':age ' || age ||':medication ' || drug_name || ':' || outcome_during_hospitalization ||':Ward ' || 
	admission_ward, ',')into patient_details 
    FROM public.demography d join public.patient_precriptions using (inpatient_number) join  public.hospitalization_discharge
    using (inpatient_number) where d.inpatient_number = patient_number;
    return  patient_details ;
END;
$$ language plpgsql;

select patient_details_csv(743087);
--41. Which patients were on more than 15 prescribed drugs? What was their age and outcome? 
--   how the results without using a subquery

--QUERY:
SELECT * FROM demography
	
ALTER TABLE demography
ADD COLUMN age int;

UPDATE demography
SET age = CASE
	WHEN agecat = '21-29' THEN
FLOOR(21 +RANDOM()* 9)
    WHEN agecat = '29-39' THEN
FLOOR(29 +RANDOM()* 11)
    WHEN agecat = '39-49' THEN
FLOOR(39 +RANDOM()* 11)
   WHEN agecat = '49-59' THEN
FLOOR(49 +RANDOM()* 11)
   WHEN agecat = '59-69' THEN
FLOOR(59 +RANDOM()* 11)
   WHEN agecat = '69-79' THEN
FLOOR(69 +RANDOM()* 11)
    WHEN agecat = '79-89' THEN
FLOOR(79 +RANDOM()* 11)
     WHEN agecat = '89-110' THEN
FLOOR(89 +RANDOM()* 22)
    ELSE age
END;

with patient_drugs as (
select p.inpatient_number, count(drug_name) as drugs , age, outcome_during_hospitalization from public.patient_precriptions p join public.demography d 
on p.inpatient_number = d.inpatient_number
join public.hospitalization_discharge h	on p.inpatient_number=h.inpatient_number
group by p.inpatient_number , age , outcome_during_hospitalization
having count(drug_name) > 15 )	
select inpatient_number, age , outcome_during_hospitalization , drugs from patient_drugs

--42. Write a PLSQL block to return the patient ID and gender from demography for a patient if the ID exists and raise an exception if the patient id is not found. 
--	Do this without writing or storing a function. Patient ID can be hard-coded for the block	
--QUERY:
do $$
declare
	p_id integer := 743087;
	p_gender varchar(20);
	p_exists boolean;
begin
	select exists(select inpatient_number from  public.demography where inpatient_number = p_id ) into p_exists;
    select gender into p_gender from public.demography where inpatient_number = p_id ;

	if p_exists then
	 raise notice 'id:% ', p_id || ',' || ' gender:'  || p_gender ;
	else
	 raise notice 'patient id % does not exists in the table.' , p_id;
	END IF;
END $$;	

--43. Display any 10 random patients along with their type of heart failure

--QUERY:
SELECT inpatient_number, type_of_heart_failure FROM  public.cardiaccomplications
ORDER BY RANDOM() LIMIT 10;

--44. select drug_name from public.patient_precription

--QUERY:

SELECT drug_name, length(drug_name) 
AS "Length of unique drug Name" 
FROM public.patient_precriptions
WHERE length(drug_name)>20;


--45. Rank patients using CCI Score as your base. Use a windows function to rank them in descending order. 	With the highest no. of comorbidities ranked 1.
--QUERY:
SELECT
    inpatient_number, cci_score,
    RANK() OVER ( 
        ORDER BY cci_score desc
    ) 
FROM 
	public.patienthistory
where cci_score is not null;	

--46. What ratio of patients who are responsive to sound vs pain?
--QUERY:
WITH CTE AS
	(
	SELECT DISTINCT (consciousness), COUNT(*) 
	as patients_count FROM responsivenes
    WHERE consciousness IN ('ResponsiveToSound','ResponsiveToPain')
	group by responsivenes.consciousness
	)
SELECT 
	(SELECT patients_count FROM CTE WHERE consciousness = 'ResponsiveToSound') As Responsive_to_sound,
	(SELECT patients_count FROM CTE WHERE consciousness = 'ResponsiveToPain') AS Responsive_to_pain,
	(SELECT patients_count FROM CTE WHERE consciousness = 'ResponsiveToSound') || ':' ||
	NULLIF((SELECT patients_count FROM CTE WHERE consciousness = 'ResponsiveToPain'), 0 ) AS 	sound_to_pain_ratio;
	
--47. Use a windows function to return all admission ways along with occupation
--which is related to the highest MAP value

--QUERY:
SELECT DISTINCT(admission_way), occupation, MAX(map_value)
OVER (PARTITION BY admission_way, occupation)as max_map
FROM labs l JOIN hospitalization_discharge h ON h.inpatient_number = l.inpatient_number
JOIN demography d ON d.inpatient_number = l.inpatient_number
ORDER BY 1
--48. Display the patients with the highest BMI.

--QUERY:

select inpatient_number, bmi from  public.demography
where bmi = (select max(bmi) from public.demography);

--49. Find the list of Patients who has leukopenia.
--QUERY:
select inpatient_number from public.labs
where white_blood_cell < 4

--50. What is the most frequent weekday of admission?
 
--QUERY:
SELECT (EXTRACT(DOW FROM admission_date)) as days_of_week,
COUNT(*) as frequency
FROM hospitalization_discharge
where EXTRACT('DOW' FROM admission_date) not in (0,6)--(excluding the weekends 0-sunday, 6-saturday )
GROUP BY days_of_week
ORDER BY frequency DESC
LIMIT 1

--51. Create a console bar chart using the '▰' symbol for count of patients in any age category where theres more than 100 patients"
--QUERY:
with sq as (select agecat, count(*) as frequency  from public.demography
group by agecat
having count(*) > 100)
SELECT 
agecat,
  frequency, 
  repeat('▰', (frequency / 100)::integer) AS bar_chart
FROM 
  sq
ORDER BY 
 frequency DESC;
 
 --52. Find the variance of the patients' D_dimer value and display it along with the correlation to CCI score and display them together.
--Query:
select round(variance(d_dimer):: numeric, 2)  as variation,  round(corr(d_dimer, cci_score)::numeric,2) as correlation
from public.labs
left outer join public.patienthistory on labs.inpatient_number = public.patienthistory.inpatient_number

--53. Which adm ward had the lowest rate of Outcome Death?
select admission_ward, count(time_of_death__days_from_admission) as outcome_death_frequency from public.hospitalization_discharge
group by admission_ward
order by outcome_death_frequency
limit 1
--54.What % of those in a coma also have diabetes. Use the GCS scale to evaluate.
 --Query
SELECT
	round(COUNT(*) FILTER (WHERE gcs <= 8 AND diabetes = '1') / COUNT(*) FILTER (WHERE gcs <= 8):: numeric,2) * 100 as percentage
           	from public.responsivenes r
left outer join public.patienthistory h on r.inpatient_number = h.inpatient_number;

--55.Display the drugs prescribed for the youngest patient
--Query:
select  age,drug_name from
public.demography d
inner join public.patient_precriptions pp on d.inpatient_number = pp.inpatient_number
where age  = (select min(age) from public.demography)

---56.Create a view on the public.responsivenes table using the check constraint
Query:
DROP VIEW gcs_view2
CREATE VIEW gcs_view2  AS
(SELECT  gcs
FROM responsivenes
where gcs >8)
           	 WITH CHECK OPTION; -- run here
SELECT * FROM gcs_view2 -- run here
--Query to test the Check option:
--Test to insert value with gcs as 2.
INSERT INTO gcs_view2
VALUES(2)

--57.Determine if a word is a palindrome and display true or false. Create a temporary table and store any words of your choice for this question
--Query: 
create table palindrome (
words text );
insert into palindrome(words) values
('ete'),
('ape'),
('nine');
SELECT words,CASE WHEN words=REVERSE(words)THEN 'true'
        	ELSE 'false'
        	END 
from palindrome;

 ---58. How many visits were common among those with a readmission in 6 months
--Query:
select count(*) as frequency_of_patientsinreadmission_in6months, visit_times as most_common_visits
from public.hospitalization_discharge
where re_admission_within_6_months =1
group by visit_times
order by frequency_of_patientsinreadmission_in6months desc
limit 1

--59. What is the size of the database Cardiac_Failure
--Query:
select pg_database_size('Cardiac_Failure');

---60.Find the greatest common denominator and the lowest common multiple of the numbers 365 and 300. show it in one query
--Query:
select lcm(365,300) as LCM, gcd(365,300) as GCD
--61.Group patients by destination of discharge and show what % of all patients in each group was re-admitted within 28 days.Partition these groups as 2: high rate of readmission, low rate of re-admission. Use windows functions
--Query:
WITH
  -- Calculate total readmitted patients by destination discharge
  readmitted_patients AS (
	SELECT
      destinationdischarge,
      SUM(re_admission_within_28_days) AS total_readmitted
	FROM
      public.hospitalization_discharge
	WHERE
      re_admission_within_28_days = 1
	GROUP BY
      destinationdischarge
  ),
 
  -- Calculate readmission rate and partition into high/low categories
  readmission_rate AS (
	SELECT
      rd.destinationdischarge,
  	COUNT(*) AS total_patients,
      rp.total_readmitted,
      ROUND((rp.total_readmitted / COUNT(*) * 100), 2) AS readmission_rate,
  	NTILE(2) OVER (ORDER BY (rp.total_readmitted / COUNT(*) * 100) DESC) AS partition
	FROM
      public.hospitalization_discharge rd
	JOIN
      readmitted_patients rp ON rd.destinationdischarge = rp.destinationdischarge
	GROUP BY
      rd.destinationdischarge, rp.total_readmitted
  )
 
-- Classify destinations into high/low readmission rate categories
SELECT
  destinationdischarge,
  total_patients,
  total_readmitted,
  readmission_rate,
  CASE
	WHEN partition = 1 THEN 'High Rate of Readmission'
	ELSE 'Low Rate of Readmission'
  END AS category
FROM
  readmission_rate
ORDER BY
  readmission_rate DESC;
  
  --62. What is the size of the table labs in KB without the indexes or additional objects
--Query:
SELECT   pg_size_pretty (pg_relation_size('labs')) sizeoflab;

--63. concatenate age, gender and patient ID with a ';' in between without using the || operator
--Query: 
select concat(inpatient_number,';',age,';',gender) from public.demography

--64.Display a reverse of any 5 drug names
--Query: 
select drug_name,reverse(drug_name) from public.patient_precriptions
limit 5
--65. What is the variance from mean for all patients GCS score.

--QUERY:
WITH gcs_score AS (
    SELECT AVG(gcs) AS mean_gcs
    FROM responsivenes
)
--variance(average of (xi-mean x)^2)
SELECT AVG(POWER(res.gcs - gs.mean_gcs, 2)) AS variance
FROM responsivenes res
 CROSS JOIN gcs_score gs;
 
 --66. Using a while loop and a raise notice command, print the 7 times table as the result
--QUERY:
 DO $$
DECLARE
    num INT := 1;
    result INT;
BEGIN
    WHILE num <= 10 LOOP
        result := num * 7;
        RAISE NOTICE '7 * % = %', num, result;
        num := num + 1;
    END LOOP;
END $$;
--67. Show month number and month name next to each other(admission_date), ensure that month number is always 2 digits. eg, 5 should be 05"
--QUERY:

SELECT
    inpatient_number,
    admission_date,
    TO_CHAR(admission_date, 'MM') AS month_number, 
    TO_CHAR(admission_date, 'Month') AS month_name 
FROM
    hospitalization_discharge;
	
--68. How many patients with both heart failures had kidney disease or cancer.

--QUERY:

SELECT 
    COUNT(DISTINCT p.inpatient_number) AS patient_count
FROM 
    patienthistory p
JOIN 
    cardiaccomplications c ON p.inpatient_number = c.inpatient_number
WHERE 
    c.type_of_heart_failure = 'Both' AND
    (p.moderate_to_severe_chronic_kidney_disease = 1 OR 
     p.malignant_lymphoma = 1 OR 
     p.leukemia = 1 OR
     p.acute_renal_failure = 1);
--69. Return the number of bits and the number of characters for every value in the column: Occupation

--QUERY:

SELECT 
    inpatient_number,
    occupation,
    LENGTH(occupation) AS num_of_chars,
    LENGTH(occupation) * 8 AS num_of_bits
FROM 
    demography;
	
--70. Create a stored procedure that adds a column to table cardiaccomplications. The column should just be the todays date
--QUERY:
	
CREATE OR REPLACE PROCEDURE AddTodaysDateColumn()	
LANGUAGE plpgsql	
AS $$	
BEGIN	
    -- Check if the column 'todaysdate' exists	
    IF NOT EXISTS (	
        SELECT 1	
        FROM information_schema.columns	
        WHERE table_name = 'cardiaccomplications'	
        AND column_name = 'todaysdate'	
    ) THEN		
        EXECUTE 'ALTER TABLE cardiaccomplications ADD COLUMN todaysdate DATE DEFAULT CURRENT_DATE';	
    END IF;	
END;	
$$;	
CALL AddTodaysDateColumn();	

--71. What is the 2nd highest BMI of the patients with 5 highest myoglobin values. Use windows functions in solution
--QUERY:

WITH RankedMyoglobin AS (
    SELECT inpatient_number, myoglobin,
        RANK() OVER (ORDER BY myoglobin DESC) AS myoglobin_rank
    FROM labs
	WHERE myoglobin IS NOT NULL
),
TopPatients AS (
    SELECT dm.inpatient_number, dm.bmi
    FROM demography dm
    JOIN RankedMyoglobin rm ON dm.inpatient_number = rm.inpatient_number
    WHERE rm.myoglobin_rank <= 5
)
SELECT inpatient_number, bmi
FROM TopPatients
ORDER BY bmi DESC
OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY;  -- This gets the second highest BMI with 5 highest myoglobin values.

--72. What is the standard deviation from mean for all patients pulse
--QUERY:

SELECT 
    AVG(pulse) AS mean_pulse,
    STDDEV(pulse) AS stddev_pulse
FROM 
    labs;
--73. Create a procedure to drop the age column from demography
--QUERY:
DROP PROCEDURE IF EXISTS drop_age_column();

CREATE OR REPLACE PROCEDURE drop_age_column()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if the column exists, then drop it
    IF EXISTS (SELECT 1
               FROM information_schema.columns
               WHERE table_name = 'demography'
                 AND column_name = 'age') THEN
        ALTER TABLE demography
        DROP COLUMN age;
    END IF;
END;
$$;
CALL drop_age_column();
--SELECT * FROM demography

	
--74. What was the average CCI score for those with a BMI>30 vs for those <30
--QUERY:
SELECT 
    CASE WHEN d.bmi > 30 THEN '> 30' ELSE '<= 30' END AS bmi_category,
    AVG(ph.cci_score) AS average_cci_score
FROM demography d
JOIN patienthistory ph ON d.inpatient_number = ph.inpatient_number
GROUP BY bmi_category;
--75. Write a trigger after insert on the Patient Demography table. if the BMI >40, warn for high risk of heart risks
--QUERY:

CREATE OR REPLACE FUNCTION warn_high_risk_heart() 
RETURNS TRIGGER AS $$
BEGIN
    -- Check if BMI is greater than 40
    IF NEW.BMI > 40 THEN
        -- Raise a warning for high heart risk
        RAISE NOTICE 'Warning: Patient % has a BMI of %, which indicates a high risk of heart issues.', NEW.inpatient_number, NEW.BMI;
    END IF;
    
    -- Return the new record (this is required for an AFTER INSERT trigger)
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER after_insert_bmi_check
AFTER INSERT ON demography
FOR EACH ROW
EXECUTE FUNCTION warn_high_risk_heart();


--76. Most obese patients belong to which age group and gender. You may make an assumption for what qualifies as obese based on your research
--QUERY:

SELECT  agecat, gender, COUNT(*) AS obese_patient_count
FROM  demography
WHERE bmi >= 30
GROUP BY  agecat, gender
ORDER BY   obese_patient_count DESC
LIMIT 1;

--77. Show all response details of a patient in a JSON array

--QUERY:
SELECT 
    json_agg(responsivenes) AS response_detail_of_a_patient
FROM 
    responsivenes
WHERE 
    inpatient_number = 857781;
	
	
--78. Update the table public.patienthistory. Set type_ii_respiratory_failure to be upper case,query the results of the updated table without writing a second query

--QUERY:
UPDATE public.patienthistory
SET type_ii_respiratory_failure = UPPER(type_ii_respiratory_failure)
RETURNING *;

--79. Find all patients using Digoxin or Furosemide using regex
--QUERY:
SELECT inpatient_number, drug_name
FROM patient_precriptions
WHERE drug_name ~* '(Digoxin|Furosemide)';

---80. Using a recursive query, show any 10 patients linked to the drug: "Furosemide injection"


WITH RECURSIVE first10patient AS 
(
	SELECT *
	FROM patient_precriptions
    WHERE drug_name = 'Furosemide injection'
UNION ALL
SELECT p.*  FROM patient_precriptions p
    
    JOIN first10patient  ON first10patient.inpatient_number= p.inpatient_number)
	SELECT * FROM first10patient
	LIMIT 10








