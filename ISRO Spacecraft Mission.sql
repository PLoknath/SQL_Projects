-- Creating database

create database isro;
use isro;

-- Creating final table structure with important constraints

create table isro_missions 
(
Sr_No int primary key,
Mission_Name varchar(255) not null,
Launch_Date varchar(255) not null,
Launch_Vehicle varchar(255),
Orbit_Type varchar(255),
Application varchar(255),
Remarks tinytext
);

/*1. Ensure Your File Is UTF-8 Encoded
Open the file in a text editor (e.g., Notepad on Windows).
Go to File → Save As.
In the "Encoding" dropdown, select UTF-8 and save it again.*/

/* Creating a tempory table in order to load dataset and performing required transformations */

create temporary table temp_isro
(
Sr_No int,
Mission_Name varchar(255),
Launch_Date varchar(255),
Launch_Vehicle varchar(255),
Orbit_Type varchar(255),
Application varchar(255),
Remarks tinytext
);
 
load data infile "C:/Odin scool project dataset/ISRO mission launches.csv"
into table temp_isro
fields terminated by ","
optionally enclosed by '"'
lines terminated by "\n"
ignore 1 rows;

-- As some of the entries are missing , I'm replacing them with null
update temp_isro
set orbit_type=nullif(orbit_type,""),
application = nullif(application,"");

-- changing datatype and format of "launch date" column

update temp_isro
set launch_date = str_to_date(launch_date,"%d-%b-%y");


-- extracting launch vehicle details and removing mission name

update temp_isro
set launch_vehicle = if(locate("/",launch_vehicle),left(launch_vehicle,locate("/",launch_vehicle)-1),launch_vehicle);

/*we can use either mid or left function
select if(locate("/",launch_vehicle),left(launch_vehicle,locate("/",launch_vehicle)-1),launch_vehicle) from temp_isro;
-- OR
select if(locate("/",launch_vehicle),mid(launch_vehicle,1,locate("/",(launch_vehicle))-1),launch_vehicle) from temp_isro;
*/

-- Checking Duplicate values

select Sr_No, Mission_Name, Launch_Date, Launch_Vehicle, Orbit_Type,
Application,  Remarks, count(*) from temp_isro
group by Sr_No, Mission_Name, Launch_Date, Launch_Vehicle, Orbit_Type,
Application,  Remarks having count(*)>1;

-- Now exporting these values into our final table "isro_missions"

insert into isro_missions (Sr_No, Mission_Name, Launch_Date, Launch_Vehicle, Orbit_Type,
Application,  Remarks)
(select Sr_No, Mission_Name, Launch_Date, Launch_Vehicle, Orbit_Type,
Application,  Remarks from temp_isro);
---------------------------------------------------------------------------------------------------------------------------------------------------------

/* Now our table is ready for analysis */
-- Performing Queries

-- 1. Find how many missions isro has launched
SELECT 
    COUNT(sr_no) AS total_missions
FROM
    isro_missions;

-- Isro has so far launched 125 missions
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 2. Give the name of missions which were successful
SELECT 
    mission_name
FROM
    isro_missions
WHERE
    Remarks REGEXP '^Launch successful';

-- Out of 125 missions 112 missions had launched succcessful
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 3. What are distinct orbits types
SELECT 
    orbit_type
FROM
    isro_missions
GROUP BY orbit_type
HAVING orbit_type IS NOT NULL;

-- LEO, GSO, SSPO, Lunar, GEO, Martian, GTO
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 4. From how many years isro is active
SELECT 
    MIN(YEAR(launch_date)) start_year,
    MAX(YEAR(launch_date)) latest_year,
    MAX(YEAR(launch_date)) - MIN(YEAR(launch_date)) AS active_years
FROM
    isro_missions;

-- ISRO is active from last 48 years.
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Find details of the first and the latest mission launched by isro
SELECT * FROM
    isro_missions
WHERE
    launch_date = (SELECT MIN(launch_date)
					FROM isro_missions)
	OR launch_date = (SELECT MAX(launch_date)
						  FROM isro_missions);
            
-- First mission was "Aryabhata" in year 1975 and 
-- latest mission was "Aditya- l1" in year 2023
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 6. Find the launch vehicle which has been used for most number of times.
SELECT 
    launch_vehicle, COUNT(launch_vehicle) AS mission_count
FROM
    isro_missions
GROUP BY launch_vehicle
ORDER BY mission_count DESC
LIMIT 1;

-- PSLV-C54 has been used for 5 times
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 7. Find the year when most of the successful launches happened
with s_mission as 
(select year, count(mission_name) as successful_missions 
from (select year(launch_date) as year, mission_name 
	  from isro_missions 
      where remarks like "%Launch successful%") as s_missions
      group by year), 

ranking as
(select year, successful_missions, 
		rank() over(order by successful_missions desc) as rnk 
from s_mission)

select * from ranking where rnk = 1;

-- In year 2018 and 2022 the successful missions accomplished were 9 in each year
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 8. Find number of missions launched per applications count
with mission_details as
(select Application, 
		count(Launch_Vehicle) as mission_count, 
        (select count(Mission_Name) from isro_missions) as total_missions
from isro_missions 
group by Application 
order by mission_count desc),

percentage as
(select Application, 
        round(mission_count/total_missions*100,2) as percent 
from mission_details)

select * from percentage p1 
where 3>=(select count(application) from percentage p2 where p1.percent <=p2.percent);

-- most of the launches focused on communicationn applications 30.40%
-- followed by earth obervation at 28.80% experimental at 8.80%
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 9. Find all missions launched with PSLV launch vehicles.
SELECT *
FROM isro_missions
WHERE launch_vehicle REGEXP '^pslv.*';
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 10. Get the total number of missions launched for 'Planetary Observation'.
SELECT 
    application, COUNT(application) mission_count
FROM
    isro_missions
WHERE application REGEXP '^Planetary Observation$'
GROUP BY application;

-- 5 missions were launched for planetary observation application
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 11. List missions with 'Earth Observation' as their application, ordered by date.
SELECT 
    launch_date, mission_name, application
FROM
    isro_missions
WHERE application REGEXP '^Earth Observation$'
ORDER BY launch_date;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 12. Show the missions launched in 2023.
SELECT 
    YEAR(launch_date) AS year, mission_name, application
FROM
    isro_missions
WHERE YEAR(launch_date) = 2023;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 13. Get the number of missions for each orbit type.
SELECT 
    orbit_type, COUNT(orbit_type) mission_count
FROM
    isro_missions
GROUP BY orbit_type
ORDER BY mission_count DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 14. Find all missions with 'Experimental' as an application, excluding those marked unsuccessful.
SELECT *
FROM
    isro_missions
WHERE application REGEXP '^.*experimental.*'
	  AND remarks REGEXP '^launch successful';
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 15. List the distinct years in which missions failed.
SELECT DISTINCT
    YEAR(launch_date) AS year, mission_name, remarks
FROM
    isro_missions
WHERE
    remarks NOT REGEXP '^launch successful'
ORDER BY year;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 16. Show the launch vehicle with the highest number of successful launches.
SELECT 
    IF(LENGTH(LEFT(launch_vehicle, LOCATE('-', launch_vehicle))) < 4,launch_vehicle,
              LEFT(launch_vehicle,LOCATE('-', launch_vehicle) - 1)) AS launch_veh,
    COUNT(mission_name) mission_count
FROM
    isro_missions
WHERE
    remarks REGEXP '^launch successful'
GROUP BY launch_veh
ORDER BY mission_count DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 17. Get the first mission launched into Lunar orbit.
select * from (select *, 
               row_number() over(order by launch_date) as rnk 
               from isro_missions where orbit_type regexp "^.*lunar.*") 
               as ranking
where rnk=1;

-- The first mission for lunar orbit was Chandrayan-1 ,launched on 2008-10-22
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 18. List all missions that occurred after Mars Orbiter Mission.
SELECT * FROM isro_missions
WHERE sr_no > (SELECT sr_no
				FROM
					isro_missions
				WHERE
					mission_name REGEXP '^.*mars orbiter mission');
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 19. Get the cumulative number of missions launched year by year.
select 
      year(launch_date) as year, 
      count(mission_name) over(order by year(launch_date)) 
from isro_missions;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 20. Identify the launch vehicle used most often for Earth Observation missions.
select 
      launch_vehicle, 
      count(launch_vehicle) as mission_count from isro_missions 
where application regexp "^.*earth observation.*$"
group by launch_vehicle 
order by mission_count 
desc limit 1;

-- PSLV-C54 is most often used 
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 21. List the top 3 most frequent applications.
select * from 
      (select application, 
              count(application) as a_count, 
              dense_rank() over(order by count(application) desc) as rnk 
	   from isro_missions
       group by application 
       order by a_count desc) as ranking 
where rnk <=3;

-- Communication, earth observation and experimental are frequent applications
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 22. Show the latest unsuccessful mission.
SELECT *
FROM
    isro_missions
WHERE launch_date = (SELECT MAX(launch_date)
                    FROM
                         isro_missions
					WHERE remarks REGEXP '^.*unsuccessful.*');
                    
-- EOS-03 mission was unsuccessful on 2021-08-12
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 23. Find all missions between 2010 and 2020 with successful launches.
SELECT 
    YEAR(launch_date), mission_name
FROM
    isro_missions
WHERE YEAR(launch_date) BETWEEN 2010 AND 2020;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 24. Calculate the average number of missions launched per year.
SELECT 
    AVG(mission_count)
FROM
    (SELECT 
        COUNT(mission_name) AS mission_count
    FROM
        isro_missions
    GROUP BY YEAR(launch_date)) AS yearwise_mission;

-- On an average 3 missions launched per year
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 25. Get all missions with 'Climate & Environment' or 'Disaster Management System' as part of their application.
SELECT *
FROM
    isro_missions
WHERE application REGEXP 'Climate & Environment|Disaster Management System';
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 26. Rank the missions by launch date within each orbit type.
select 
     orbit_type, 
     mission_name, 
     rank() over(partition by orbit_type order by launch_date) as rnk 
from isro_missions;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 27. Find the longest gap between two consecutive missions.
with consec_missions as
     (select launch_date, 
              lag(launch_date,1) over() as prev_launch_date, 
              (launch_date - lag(launch_date,1) over()) as gap_between_missions 
      from isro_missions 
	  group by launch_date 
      order by gap_between_missions desc)

select * from consec_missions 
where gap_between_missions = (select max(gap_between_missions) 
                              from consec_missions);
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 28. Identify the launch vehicle with the least number of unsuccessful launches.
SELECT 
    launch_vehicle, COUNT(launch_vehicle) AS counts
FROM
    isro_missions
WHERE remarks NOT REGEXP '^launch successful'
GROUP BY launch_vehicle
ORDER BY counts ASC;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 29. Identify the orbit type with the most launches in the last 5 years.
SELECT 
    YEAR(Launch_Date), orbit_type, COUNT(orbit_type) AS count
FROM
    isro_missions
WHERE launch_date >= (select (max(Launch_Date) - INTERVAL 5 YEAR) from isro_missions)
GROUP BY YEAR(Launch_Date) , orbit_type;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 30. Get the percentage of successful launches.
with successful_launch as
(select (select count(mission_name) 
         from isro_missions 
		 where remarks regexp "^launch successful") as successful_missions,
count(Mission_Name) as total_missions from isro_missions)

select concat(round(successful_missions/total_missions*100,2)," ","%") as success_rate 
from successful_launch;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 31. Find the mission which was named as student satellite
SELECT *
FROM
    isro_missions
WHERE Application REGEXP '^student satellite';
-------------------------------------------------------------------------------------------------------------------------------------

-- 32. What is the preferred orbit for communication applications
SELECT 
    orbit_type, COUNT(*)
FROM
    isro_missions
WHERE Application REGEXP '^communication'
GROUP BY Orbit_Type;

-- for communication application prefrred orbit type is GSO (Geosynchronous Orbit)
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 33. Success rate in each orbit
with success as
(SELECT DISTINCT
    Orbit_Type, COUNT(*) as successful_mission
FROM
    isro_missions
WHERE
    remarks REGEXP '^launch successful'
GROUP BY Orbit_Type
ORDER BY COUNT(*) DESC),

total as
(SELECT DISTINCT
    Orbit_Type, COUNT(*) as total_mission
FROM
    isro_missions
GROUP BY Orbit_Type
ORDER BY COUNT(*) DESC)

SELECT 
    s.Orbit_Type,
    successful_mission,
    total_mission,
    ROUND(successful_mission / total_mission * 100) AS '%'
FROM
    success s
        JOIN
    total t ON s.Orbit_Type = t.Orbit_Type;
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- 34. orbit and application recorded most number of failures
SELECT 
    Orbit_Type, application, COUNT(Launch_Vehicle) AS count
FROM
    isro_missions
WHERE Remarks NOT REGEXP '^launch successful'
GROUP BY Orbit_Type , application
ORDER BY count DESC;

-- 7 Failed launches in GSO orbit (Geosynchronous Orbit) recorded for communication application
 ----------------------------------------------------------------------------------------------------------------------------------------------------


select * from isro_missions;