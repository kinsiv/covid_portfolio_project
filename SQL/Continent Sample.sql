
/* Employing data mining tactics to gather evidence for drawing conclusions about the impact of COVID per continent.
Total deaths, total cases are a running total so they're queried as such. 
Smooth attributes utilized to reduce randomness in results when calculating percentages or proportions.
European Union not included because the individual countries inlisted are recorded instead.

Monthly, yearly, and overall totals.Smooth attributes used to include a minorly inaccurate (<2%), yet precise totals & grand total for World - 
doubles as a method of reducing randomness and error in gathered evidence. */
SELECT location AS continent, FLOOR(SUM(new_deaths_smoothed)) AS totalDeaths, CAST(SUM(new_cases_smoothed) AS INT) AS totalInfected, 
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyDeaths,
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT year),0) AS yearlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT year),0) AS yearlyDeaths
FROM death_samples WHERE location='Africa' OR location='South America' OR location='Europe' OR location='Oceania' OR location='Asia' OR location='North America'
GROUP BY location WITH ROllUP ORDER BY totalDeaths DESC;


-- Population impact statistics. Percentages are included to determine a country's death and infection toll. Mortality rate of those who experience death after infection.
SELECT location AS continent, CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/MAX(population)*100) AS percentOfPopulationDead, 
	CONVERT(DECIMAL(4,2),SUM(new_cases_smoothed)/MAX(population)*100) AS percentOfPopulationInfected, 
	CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/NULLIF(SUM(new_cases_smoothed),0)*10) AS mortalityRate
FROM death_samples WHERE location!=continent AND location='Africa' OR location='South America' OR location='Europe' OR location='Oceania' 
	OR location='Asia' OR location='North America' 
GROUP BY location ORDER BY mortalityRate DESC;


-- Hospital intake with a percentage of infected admitted into hospital.
SELECT continent, MAX(total_cases) AS totalInfected, SUM(hosp_patients) AS hospitalIntake,
	ROUND(SUM(hosp_patients)/NULLIF(SUM(new_cases_smoothed),0)*100,2) AS percentOfHospitalIntake,
	CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/MAX(population)*100) AS percentOfPopulationDead
FROM death_samples WHERE hosp_patients>0 OR location='Africa' OR location='South America' OR location='Europe' OR location='Oceania' 
	OR location='Asia' OR location='North America' GROUP BY continent ORDER BY continent, percentOfHospitalIntake DESC;


-- Total vaccinations and people vaccinated. Percentage of vaccinations utilized, population fully vaccinated, and boosters.
SELECT ds.location, MAX(total_vaccinations) AS totalVaccinations, MAX(people_vaccinated) AS totalPeopleVaccinated, MAX(total_boosters) AS totalBoosters,
	ROUND(MAX(people_vaccinated)/NULLIF(MAX(total_vaccinations)-MAX(total_boosters),0)*100, 2) AS percentVaccinationsUtilized,
	CAST(MAX(people_fully_vaccinated)/NULLIF(MAX(people_vaccinated),0)*100 AS DECIMAL(4,2)) AS percentFullyVaccinated,
	CAST(MAX(total_boosters)/NULLIF(MAX(total_vaccinations),0)*100 AS DECIMAL(4,2)) AS percentBoostersOfVaccinations
FROM vaccination_samples vs INNER JOIN death_samples ds ON ds.location = vs.location WHERE ds.location!=ds.continent AND ds.location='Africa' 
	OR ds.location='South America' OR ds.location='Europe' OR ds.location='Oceania' OR ds.location='Asia' OR ds.location='North America'
GROUP BY ds.location ORDER BY ds.location 


-- Infection Ranking based on total infected.
SELECT continent, MAX(total_cases) AS totalInfected, 
	CASE 
		WHEN MAX(total_cases)<14000000 THEN 'Moderately Contagious'
		WHEN MAX(total_cases) BETWEEN 14000000 AND 240000000 THEN 'Extremely Hazardous'
		ELSE 'Certain Death'
	END AS infectionRanking
FROM death_samples WHERE continent!='N/A' GROUP BY continent;
GO


-- Procedure for updating an existing record's total infections and total dead in death_samples view.
CREATE PROCEDURE dbo.update_existing_record
	@totalDeaths BIGINT,
	@totalCases BIGINT,
	@location VARCHAR(50)
AS
	SET NOCOUNT ON;
	UPDATE death_samples SET total_deaths=@totalDeaths, total_cases=@totalCases WHERE location=@location;
	SELECT location, total_deaths, total_cases FROM death_samples
	WHERE location=@location AND total_deaths=@totalDeaths AND total_cases=@totalCases;

	RETURN;

EXEC update_existing_record @totalDeaths=8154231, @totalCases=18134521, @location='South America'
GO


-- Calculates the mortality rate for a designated continent. 
CREATE FUNCTION dbo.mortalityRate (@location VARCHAR(50))
RETURNS FLOAT
AS
BEGIN
	DECLARE @population FLOAT
	SET @population=(SELECT ROUND(SUM(new_deaths_smoothed)/SUM(new_cases_smoothed)*100,2) FROM death_samples WHERE location=@location)
	RETURN @population
END;
GO

SELECT dbo.mortalityRate('North America') AS mortalityRate;