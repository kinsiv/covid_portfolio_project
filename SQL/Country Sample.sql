
/* Employing data mining tactics to gather evidence for drawing conclusions about the impact of COVID per country.
Total deaths, total cases are a running total so they're queried as such.
Smooth attributes utilized to reduce randomness in results when calculating percentages or proportions.
European Union not included because the individual countries inlisted are recorded instead.

Monthly, yearly, and overall totals. Smooth attributes used to include a minorly inaccurate (<2%), yet precise totals & grand total for World - 
doubles as a method of reducing randomness and error in gathered evidence. Population and median ages are subqueried for future correlation examination. */
SELECT location, (SELECT CONVERT(INT,MAX(population_density)) FROM vaccination_samples vs WHERE death_samples.location=vs.location) AS population_density,
	(SELECT FLOOR(MAX(median_age)) FROM vaccination_samples vs WHERE death_samples.location=vs.location) AS median_age,
	FLOOR(SUM(new_deaths_smoothed)) AS totalDeaths, CAST(SUM(new_cases_smoothed) AS INT) AS totalInfected, 
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyDeaths,
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT year),0) AS yearlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT year),0) AS yearlyDeaths
FROM death_samples WHERE location!=continent AND location!='Oceania' AND location!='European Union' AND location!='World' AND location NOT LIKE '%income%' 
GROUP BY location WITH ROllUP ORDER BY totalDeaths DESC;


/*Population impact statistics. Includes handwashing facilities and hospital beds for correlation examination of mortality rate.
Percentages are included to determine a country's death and infection toll. Mortality rate of those who experience death after infection. */
SELECT location, (SELECT CAST(AVG(handwashing_facilities) AS SMALLINT) FROM vaccination_samples vs WHERE death_samples.location=vs.location) AS handwashFacilities, 
	(SELECT CAST(AVG(hospital_beds_per_thousand) AS SMALLINT) FROM vaccination_samples vs WHERE death_samples.location=vs.location) AS hospitalBedsByThousand, 
	CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/MAX(population)*100) AS percentOfPopulationDead, CONVERT(DECIMAL(4,2),SUM(new_cases_smoothed)/MAX(population)*100) 
	AS percentOfPopulationInfected, CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/NULLIF(SUM(new_cases_smoothed),0)*10) AS mortalityRate
FROM death_samples WHERE (SELECT AVG(handwashing_facilities) FROM vaccination_samples vs WHERE death_samples.location=vs.location)>0 AND 
	(SELECT AVG(hospital_beds_per_thousand) FROM vaccination_samples vs WHERE death_samples.location=vs.location)>0 AND location!=continent AND 
	location!='World' AND location!='European Union' AND location!='Oceania' AND location NOT LIKE '%income%' GROUP BY location ORDER BY mortalityRate DESC;


-- Hospital intake with a percentage of infected admitted into hospital.
SELECT location, MAX(total_cases) AS totalInfected, SUM(hosp_patients) AS hospitalIntake,
	ROUND(SUM(hosp_patients)/NULLIF(SUM(new_cases_smoothed),0)*100,2) AS percentOfHospitalIntake,
	CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/MAX(population)*100) AS percentOfPopulationDead
FROM death_samples WHERE hosp_patients>0 GROUP BY location ORDER BY percentOfHospitalIntake DESC;


-- Total vaccinations and people vaccinated. Percentage of vaccinations utlized, population fully vaccinated, and boosters.
SELECT ds.location, MAX(total_vaccinations) AS totalVaccinations, MAX(people_vaccinated) AS totalPeopleVaccinated, MAX(total_boosters) AS totalBoosters,
	ROUND(MAX(people_vaccinated)/NULLIF(MAX(total_vaccinations)-MAX(total_boosters),0)*100, 2) AS percentVaccinationsUtilized,
	ROUND(MAX(people_fully_vaccinated)/NULLIF(MAX(people_vaccinated),0)*100,2) AS percentFullyVaccinated,
	ROUND(MAX(total_boosters)/NULLIF(MAX(total_vaccinations),0)*100,2) AS percentBoostersOfVaccinations, CONVERT(INT, MAX(gdp_per_capita)) AS gdpPerCapita
FROM vaccination_samples vs INNER JOIN death_samples ds ON ds.location = vs.location WHERE ds.location!=ds.continent AND total_vaccinations>0
	AND ds.location!='World' AND ds.location!='European Union' AND ds.location NOT LIKE '%income%' AND ds.location!='Oceania'
GROUP BY ds.location ORDER BY ds.location


-- Infection ranking based on total infected.
SELECT location, MAX(total_cases) AS totalInfected, 
	CASE 
		WHEN MAX(total_cases)=0 THEN 'Nonexistant'
		WHEN MAX(total_cases) BETWEEN 1 AND 1999999 THEN 'Moderately Contagious'
		WHEN MAX(total_cases) BETWEEN 2000000 AND 10000000 THEN 'Extremely Hazardous'
		ELSE 'Certain Death'
	END AS infectionRanking
FROM death_samples WHERE location!='European Union' AND location!= 'Oceania' AND location!='World' AND location NOT LIKE '%income%' 
GROUP BY location ORDER BY location;
GO


-- Procedure for inserting a new record into the death_samples view.
CREATE PROCEDURE dbo.update_death_samples
	@continent VARCHAR(20),
	@location VARCHAR(50),
	@date DATE,
	@population BIGINT,
	@totalDead BIGINT,
	@totalNewDead INT,
	@totalInfected BIGINT,
	@totalNewInfected INT,
	@hospitalPatients BIGINT
AS
	SET NOCOUNT ON;
	INSERT INTO death_samples (continent, location, date, population, total_deaths, new_deaths, total_cases, new_cases, hosp_patients)
	VALUES (@continent, @location, @date, @population, @totalDead, @totalNewDead, @totalInfected, @totalNewInfected, @hospitalPatients);
	SELECT * FROM death_samples WHERE location=@location AND date=@date AND total_deaths=@totalDead AND total_cases=@totalDead;

	RETURN;

EXEC update_death_samples @continent='Australia', @location='Syndney', @date='2023-07-01', @population=410250, @totalDead=56780,
	@totalNewDead=332, @totalInfected=121780, @totalNewInfected=501, @hospitalPatients=241;

DELETE FROM dbo.death_samples WHERE continent='Australia' AND date='2023-07-01' AND population=410250 AND hosp_patients=241;
GO


-- Calculates the mortality rate for designated country. 
CREATE FUNCTION dbo.mortalityRate (@location VARCHAR(20))
RETURNS FLOAT
AS
BEGIN
	DECLARE @population FLOAT
	SET @population=(SELECT CAST(SUM(new_deaths_smoothed)/SUM(new_cases_smoothed)*100 AS INT) FROM death_samples WHERE location=@location)
	RETURN @population
END;
GO

SELECT dbo.mortalityRate('Peru') AS mortalityRate;