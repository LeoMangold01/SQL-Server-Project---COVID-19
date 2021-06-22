 -- INTRODUCTION

 -- The aim of this workplace is to practice SQL with COVID-19 excel files downloaded (and modified before
 -- beggining with SQL) from Our World in Data

 -- With the porpuse of practicing joins, I have divided the data into 3 tables: deaths, vaccinations and 
 -- socioeconomics
 
 -- PART 1 - COVID-19 cases and deaths by country and continent 

-- 1.1. Looking at Total Cases vs Total Deaths evolution in Uruguay

SELECT location,
	FORMAT(date, 'd', 'de-DE') AS date1,
	REPLACE(FORMAT(CAST(total_cases AS REAL), 'N', 'de-de'), ',00', ''),
	REPLACE(FORMAT(CAST(total_deaths AS REAL), 'N', 'de-de'), ',00', ''),
	ROUND(CAST(total_deaths AS REAL) / CONVERT(REAL, total_cases) * 100, 4) AS death_percentage,
	ROUND(CAST(total_deaths AS REAL) / CAST(population AS REAL) * 100, 4) AS death_percentage_in_pop
FROM PortfolioProject..deaths
WHERE LOWER(location) LIKE 'uru%'
ORDER BY date

-- 1.2. Countries with most days with death percentage over 20% (when total cases > 100)
-- We indicate total cases > 100 to avoid high death percentage as a result of few total cases

SELECT location,
	FORMAT(date, 'd', 'de-DE') AS date1,
	ROUND(MAX(CAST(total_deaths AS REAL) / CAST(total_cases AS REAL) * 100), 2) AS max_death_percentage
FROM PortfolioProject..deaths
WHERE CAST(total_cases AS REAL) > 100
GROUP BY location, date
HAVING MAX(CAST(total_deaths AS REAL) / CAST(total_cases AS REAL) * 100) > 20
ORDER BY max_death_percentage DESC

-- 1.3. It seems Yemen presents the worst death percentages in an overwhelmingly number of days
-- Lets count hoy many days Yemen (and all other countries) presents over 20% death rates
WITH worst_death_percentages AS
	(
	SELECT location,
		FORMAT(date, 'd', 'de-DE') AS date1,
		ROUND(MAX(CAST(total_deaths AS REAL) / CAST(total_cases AS REAL) * 100), 2) AS max_death_percentage
	FROM PortfolioProject..deaths
	WHERE CAST(total_cases AS REAL) > 100
	GROUP BY location, date
	HAVING MAX(CAST(total_deaths AS REAL) / CAST(total_cases AS REAL) * 100) > 20
	)

SELECT location,
	COUNT(location) AS number_of_days
FROM worst_death_percentages
GROUP BY location
ORDER BY number_of_days DESC

-- The only countries which have had over 20% death rate (when cases > 100) are Yemen and, drastically less
-- commonly, France

-- 1.4. Countries with most cases per population

SELECT location,
	ROUND(MAX(CAST(total_cases AS REAL) / CAST(population AS REAL)) * 100, 2) AS cases_per_population
FROM PortfolioProject..deaths
GROUP BY location
ORDER BY cases_per_population DESC

-- 1.5.1. Countries with most absolute deaths

SELECT location,
	REPLACE(FORMAT(MAX(CAST(total_deaths AS REAL)), 'N', 'de-de'), ',00', '') AS total_deaths
FROM PortfolioProject..deaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY MAX(CAST(total_deaths AS REAL)) DESC

-- 1.5.2. Countries with most deaths per population

SELECT location,
	ROUND(MAX(CAST(total_deaths AS REAL) / CAST(population AS REAL) * 100), 2) AS death_per_population
FROM PortfolioProject..deaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY MAX(CAST(total_deaths AS REAL) / CAST(population AS REAL)) DESC

-- 1.6.1. Most recent information by continent
-- First lets get the population of each continent

WITH population_by_country AS
	(
	SELECT DISTINCT(location),
		continent,
		population
	FROM PortfolioProject..deaths
	WHERE continent IS NOT NULL
	),

	population_by_continent AS
	(
	SELECT continent,
		SUM(CAST(population AS REAL)) AS total_population
	FROM population_by_country
	GROUP BY continent
	)

-- 1.6.2. Lets wrap up
SELECT continent,
	REPLACE(FORMAT(CAST(total_population AS REAL), 'N', 'de-de'), ',00', '') AS total_population,
	REPLACE(FORMAT(SUM(CAST(new_cases AS REAL)), 'N', 'de-de'), ',00', '') AS total_cases,
	ROUND(SUM(CAST(new_cases AS REAL)) / SUM(CAST(total_population AS REAL)) * 100, 4) AS cases_percentage,
	REPLACE(FORMAT(SUM(CAST(new_deaths AS REAL)), 'N', 'de-de'), ',00', '') AS total_deaths,
	ROUND(SUM(CAST(new_deaths AS REAL)) / SUM(CAST(total_population AS REAL)) * 100, 4) AS deaths_percentage,
	REPLACE(FORMAT(SUM(CAST(new_tests AS REAL)), 'N', 'de-de'), ',00', '') AS total_tests,
	ROUND(SUM(CAST(new_tests AS REAL)) / SUM(CAST(total_population AS REAL)) * 100, 4) AS tests_percentage
FROM 
	(SELECT d.*,
	c.total_population
	FROM PortfolioProject..deaths AS d
	INNER JOIN population_by_continent AS c
	ON c.continent = d.continent) AS o
GROUP BY continent, total_population
ORDER BY continent ASC

-- 1.7. Deaths by continent and total

WITH total_deaths AS
	(
	SELECT 'Total' AS continent, SUM(CAST(new_deaths AS REAL)) AS deaths_total 
	FROM PortfolioProject..deaths
	WHERE continent IS NOT NULL),

	continent_deaths AS
	(
	SELECT
		continent,
		SUM(CAST(new_deaths AS REAL)) as deaths
	FROM PortfolioProject..deaths
	WHERE continent IS NOT NULL
	GROUP BY continent
	)

SELECT continent,
	REPLACE(FORMAT(deaths, 'N', 'de-de'), ',00', '') AS total_deaths
FROM continent_deaths
UNION ALL
SELECT continent,
	REPLACE(FORMAT(deaths_total, 'N', 'de-de'), ',00', '')	AS total_deaths
FROM total_deaths

-- 1.8.1. Cases advance in Uruguay, Iceland and Costa Rica

SELECT continent,
	location,
	FORMAT(date, 'd', 'de-DE') AS date1,
	REPLACE(FORMAT(CAST(new_cases AS REAL), 'N', 'de-de'), ',00', '') AS daily_cases,
	REPLACE(FORMAT(SUM(CAST(new_cases AS REAL)) OVER (PARTITION BY location ORDER BY location, date), 'N', 'de-de'), ',00', '') AS cases_accumulated_by_country,
	REPLACE(FORMAT(SUM(CONVERT(REAL, new_cases)) OVER (PARTITION BY location), 'N', 'de-de'), ',00', '') AS total_cases_by_country
FROM PortfolioProject..deaths
WHERE location IN ('Uruguay', 'Iceland', 'Costa Rica')
ORDER BY location, date

-- 1.8.2. Cases advance in Uruguay vs population

WITH popvscases AS
	(
	SELECT continent,
		location,
		date,
		FORMAT(date, 'd', 'de-DE') AS date1,
		REPLACE(FORMAT(CAST(new_cases AS REAL), 'N', 'de-de'), ',00', '') AS daily_cases,
		SUM(CAST(new_cases AS REAL)) OVER (PARTITION BY location ORDER BY location, date) AS cases_accumulated_by_country,
		REPLACE(FORMAT(SUM(CONVERT(REAL, new_cases)) OVER (PARTITION BY location), 'N', 'de-de'), ',00', '') AS total_cases_by_country
	FROM PortfolioProject..deaths
	WHERE location IN ('Uruguay')
	)

SELECT popvscases.location,
	popvscases.date1,
	popvscases.daily_cases,
	popvscases.cases_accumulated_by_country,
	ROUND((popvscases.cases_accumulated_by_country / CAST(PortfolioProject..deaths.population AS REAL)) * 100, 4) AS cases_per_population
FROM popvscases
INNER JOIN PortfolioProject..deaths
	ON popvscases.location =  PortfolioProject..deaths.location AND popvscases.date = PortfolioProject..deaths.date


-- PART 2 - Analyzing COVID-19 vaccinations

-- 2.1. Lets see vaccinations advance by country in the most previous date

-- REPLACE(FORMAT(CAST(total_population AS REAL), 'N', 'de-de'), ',00', '')

SELECT location,
	FORMAT(date, 'd', 'de-DE') AS date1,
	REPLACE(FORMAT(CAST(people_vaccinated AS REAL), 'N', 'de-de'), ',00', '') AS people_with_first_dose,
	REPLACE(FORMAT(CAST (people_fully_vaccinated AS REAL), 'N', 'de-de'), ',00', '') AS people_fully_vaccinated,
	ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population,
	ROUND(CAST(people_fully_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS fully_vaccinated_per_population
FROM PortfolioProject..vaccinations
WHERE date IN
	(SELECT MAX(date)
	FROM PortfolioProject..vaccinations)
	AND people_vaccinated IS NOT NULL AND people_fully_vaccinated IS NOT NULL
ORDER BY CAST(people_vaccinated AS REAL)/CAST(population AS REAL) * 100 DESC

-- 2.2.1. Finding the two countries with most doses per population in each continent

WITH asia AS
	(
	SELECT TOP 2 continent,
		location,
		ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population
	FROM PortfolioProject..vaccinations
	WHERE date IN
		(SELECT MAX(date)
		FROM PortfolioProject..vaccinations)
		AND continent = 'Asia'
	ORDER BY CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100 DESC
	),

	africa AS
	(
	SELECT TOP 2 continent,
		location,
		ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population
	FROM PortfolioProject..vaccinations
	WHERE date IN
		(SELECT MAX(date)
		FROM PortfolioProject..vaccinations)
		AND continent = 'Africa'
	ORDER BY CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100 DESC
	),

	europe AS
	(
	SELECT TOP 2 continent,
		location,
		ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population
	FROM PortfolioProject..vaccinations
	WHERE date IN
		(SELECT MAX(date)
		FROM PortfolioProject..vaccinations)
		AND continent = 'Europe'
	ORDER BY CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100 DESC
	),

	north_america AS
	(
	SELECT TOP 2 continent,
		location,
		ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population
	FROM PortfolioProject..vaccinations
	WHERE date IN
		(SELECT MAX(date)
		FROM PortfolioProject..vaccinations)
		AND continent = 'North America'
	ORDER BY CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100 DESC
	),

	oceania AS
	(
	SELECT TOP 2 continent,
		location,
		ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population
	FROM PortfolioProject..vaccinations
	WHERE date IN
		(SELECT MAX(date)
		FROM PortfolioProject..vaccinations)
		AND continent = 'Oceania'
	ORDER BY CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100 DESC
	),

	south_america AS
	(
	SELECT TOP 2 continent,
		location,
		ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS first_dose_per_population
	FROM PortfolioProject..vaccinations
	WHERE date IN
		(SELECT MAX(date)
		FROM PortfolioProject..vaccinations)
		AND continent = 'South America'
	ORDER BY CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100 DESC
	),

	all_continents AS
	(
	SELECT * FROM asia
	UNION ALL
	SELECT * FROM africa
	UNION ALL
	SELECT * FROM europe
	UNION ALL
	SELECT * FROM north_america
	UNION ALL
	SELECT * FROM oceania
	UNION ALL
	SELECT * FROM south_america
	)

SELECT *
FROM all_continents
WHERE first_dose_per_population IS NOT NULL
ORDER BY first_dose_per_population DESC

-- 2.2.2. Creating a Temporary Table based on the previous query

DROP TABLE IF EXISTS #TopVaccinatedCountries
CREATE TABLE #TopVaccinatedCountries
(
continent nvarchar(200),
location nvarchar (200),
first_dose_per_population numeric(10,4)
)

INSERT INTO #TopVaccinatedCountries (continent, location, first_dose_per_population)
SELECT *
FROM all_continents
WHERE first_dose_per_population IS NOT NULL
ORDER BY first_dose_per_population DESC

SELECT *
FROM #TopVaccinatedCountries

-- PART 3 - Relation between a country socioeconomic factors and its fight against COVID-19
-- We will analyze countries economic development (GDP per capita and poverty) and whether or not it impacts 
-- COVID-19 figures
-- Also, we will look at social factors (life expectancy, population density and handwashing facilities)

-- 3.1. Economic development by country

-- 3.1.1 Extreme Poverty and COVID-19

-- As a first step, we will create our table
WITH poverty_table AS
(
SELECT so.location,
	so.continent,
	so.extreme_poverty,
	de.total_cases,
	de.total_deaths,
	de.population,
	va.people_vaccinated,
	va.people_fully_vaccinated
FROM PortfolioProject..socioeconomics AS so
INNER JOIN PortfolioProject..deaths AS de
ON so.location = de.location AND so.date = de.date
INNER JOIN PortfolioProject..vaccinations AS va
ON so.location = va.location AND so.date = va.date
WHERE so.date IN
	(SELECT MAX(date)
	FROM PortfolioProject..socioeconomics)
)

-- Extreme poverty and COVID-19 cases

--SELECT extreme_poverty,
--	ROUND(AVG(CAST(total_cases AS REAL) / CAST(population AS REAL)) * 100, 4) AS total_cases_per_population
--FROM poverty_table
--WHERE extreme_poverty IS NOT NULL
--GROUP BY extreme_poverty
--ORDER BY total_cases_per_population DESC

-- Extreme poverty does not seem to imply more COVID-19 cases. How about deaths and vaccinations?

-- Extreme poverty and COVID-19 deaths

--SELECT extreme_poverty,
--	ROUND(AVG(CAST(total_deaths AS REAL) / CAST(population AS REAL)) * 100, 4) AS total_deaths_per_population
--FROM poverty_table
--WHERE extreme_poverty IS NOT NULL
--GROUP BY extreme_poverty
--ORDER BY CAST(extreme_poverty AS REAL) DESC

-- Contrary to that popular belief, countries with more extreme poverty have less COVID-19 deaths per population
-- We will expand on this in the next section (GDP)

-- Extreme poverty and vaccinations

-- In the first place, people vaccinated. Unfortunately, we do not have vaccinations data for countries with 
-- most extreme poverty
-- Therefore, we are obliged to narrow our analysis

--SELECT extreme_poverty,
--	ROUND(AVG(CAST(people_vaccinated AS REAL) / CAST(population AS REAL)) * 100, 4) AS people_vaccinated_per_population
--FROM poverty_table
--WHERE extreme_poverty IS NOT NULL AND people_vaccinated IS NOT NULL
--GROUP BY extreme_poverty
--ORDER BY CAST(extreme_poverty AS REAL) DESC

-- Here we see an negativa but imperfect relationship between extreme poverty and people vaccinated per population
-- We must keep in mind that the poverty range in this table is limited (only gets to 22.7) because of NULL data

-- Lets conclude our extreme poverty section analyzing people fully vaccinated 
SELECT extreme_poverty,
	ROUND(AVG(CAST(people_fully_vaccinated AS REAL) / CAST(population AS REAL)) * 100, 4) AS people_fully_vaccinated_per_population
FROM poverty_table
WHERE extreme_poverty IS NOT NULL AND people_fully_vaccinated IS NOT NULL
GROUP BY extreme_poverty
ORDER BY CAST(extreme_poverty AS REAL) DESC

-- Similarly as with people vaccinated, there seems to be a negative but imperfect relationship between extreme poverty
-- and people fully vaccinated

-- 3.1.1 Extreme Poverty and COVID-19 Conclusions

-- Interestingly, extreme poverty does not seem to imply higher COVID-19 cases or deaths (measured against population).
-- Where extreme poverty does play a role, is in vaccinations: in general lines, more extreme poverty results in
-- fewer people vaccinated (partially and fully)

-- 3.1.2 GDP and COVID-19

-- Firstly, lets create our table

WITH gdp_table AS
	(
	SELECT so.location,
		so.continent,
		so.gdp_per_capita,
		de.total_cases,
		de.total_deaths,
		de.population,
		va.people_vaccinated,
		va.people_fully_vaccinated
	FROM PortfolioProject..socioeconomics AS so
	INNER JOIN PortfolioProject..deaths AS de
	ON so.location = de.location AND so.date = de.date
	INNER JOIN PortfolioProject..vaccinations AS va
	ON so.location = va.location AND so.date = va.date
	WHERE so.continent IS NOT NULL 
		AND so.gdp_per_capita IS NOT NULL 
		AND de.total_cases IS NOT NULL
		AND so.date IN
		(SELECT MAX(date)
		FROM PortfolioProject..socioeconomics)
		)

-- Countries GDP per capita and COVID-19 cases

--SELECT location,
--	ROUND(CAST(total_cases AS REAL) / CAST(population AS REAL) * 100, 2) AS total_cases_per_population,
--	REPLACE(FORMAT(ROUND((gdp_per_capita/1000),0), 'N', 'de-de'), ',00', '') AS gdp_per_capita
--FROM gdp_table
--ORDER BY total_cases_per_population DESC

-- Countries GDP does not impact COVID-19 cases in their populations, which is consistent with
-- extreme poverty having no impact in COVID-19 cases

-- Countries GDP and COVID-19 deaths

--SELECT location,
--	ROUND(CAST(total_deaths AS REAL) / CAST(population AS REAL) * 100, 2) AS total_deaths_per_population,
--	REPLACE(FORMAT(ROUND((gdp_per_capita/1000),0), 'N', 'de-de'), ',00', '') AS gdp_per_capita
--FROM gdp_table
--ORDER BY total_deaths_per_population DESC

-- Countries GDP have no impact in COVID-19 cases, in line with extreme poverty not impacting COVID-19 deaths

-- Countries GDP and vaccinations

-- First, people vaccinated. Once again (same as with extreme poverty) we have no data for many vaccinations.
-- So our analysis of vaccinations and gdp per capita is (once again) limited to fewer cases

--SELECT location,
--	ROUND(CAST(people_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS people_vaccinated_per_population,
--	REPLACE(FORMAT(ROUND((gdp_per_capita/1000),0), 'N', 'de-de'), ',00', '') AS gdp_per_capita
--FROM gdp_table
--WHERE people_vaccinated IS NOT NULL
--ORDER BY people_vaccinated_per_population

-- Secondly, people fully vaccinated (same comment as people vaccinated)

SELECT location,
	ROUND(CAST(people_fully_vaccinated AS REAL) / CAST(population AS REAL) * 100, 2) AS people_fully_vaccinated_per_population,
	REPLACE(FORMAT(ROUND((gdp_per_capita/1000),0), 'N', 'de-de'), ',00', '') AS gdp_per_capita
FROM gdp_table
WHERE people_fully_vaccinated IS NOT NULL
ORDER BY people_fully_vaccinated_per_population

-- Contrary to the results we obtained when observing extreme poverty and vaccinations (imperfect negative 
-- relationship), there appears to be no relationship between a countries GDP per capita and vaccinations
-- per population

-- 3.1.2 GDP and COVID-19 Conclusions

-- Data shows no relationship between a country GDP per capita and its COVID-19 cases, deaths or vaccinations

-- 3.1. Economic development by country (GDP per capita and extreme poverty) Conclusions

-- Having analyzed a country development by GDP per capita and extreme poverty, we see no clear relationship.
-- Countries sttrugle against COVID-19 cases and deaths with no regards of their economic strenght. Also, economic
-- resources has no impact on vaccinations.
-- The only impact of a country economy is between extreme poverty and vaccinations since, the first has a moderate
-- negative effect on the latter

-- What could be the cause? Some thoughts:
-- A. COVID-19 burst was unexpected and swift. Generally speaking, countries with resources both limited and abundants 
-- refused to take actions until too late.
-- B. Shutting the economy via quarantine hurts the economy in both rich and poor countries. As a result, both high 
-- and low gdp_per_capita countries had difficulties implementing strict quarantines to lower cases and deaths
-- C. Even assuming richer countries could access vaccums earlier and in greater numbers, vaccunations is generally
-- optional by the population, therefore diminishing gdp_per_capita impact on vaccinations. What is more, vaccination
-- is a gradual process which could take months or even over a year to immunize a significant proportion of a country
-- population, regarthless of its resources

-- All things considered, it looks like effective and swift political actions and not robust resources explains
-- why some countries do better in keeping their populations safe

-- Lets now turn our attention to social factors such as life expectancy, population density and handwashing facilities

-- 3.2. Social development by country

-- 3.2.1. Life expectancy and COVID-19

-- Creating the table

WITH so_table AS
	(
	SELECT so.location,
		so.continent,
		so.population,
		so.population_density,
		so.median_age,
		so.handwashing_facilities,
		so.life_expectancy,
		de.total_cases,
		de.total_deaths,
		va.people_vaccinated,
		va.people_fully_vaccinated
FROM PortfolioProject..socioeconomics AS so
INNER JOIN PortfolioProject..deaths AS de
ON so.location = de.location AND so.date = de.date
INNER JOIN PortfolioProject..vaccinations AS va
ON so.location = va.location AND so.date = va.date
WHERE so.continent IS NOT NULL 
	AND de.total_cases IS NOT NULL
	AND so.date IN
		(SELECT MAX(date)
		FROM PortfolioProject..socioeconomics)
	),

	sole_table AS
	(
	SELECT *,
		(CASE
		WHEN CAST(life_expectancy AS REAL) < 60 THEN 'Very Low'
		WHEN 60 <= CAST(life_expectancy AS REAL) AND CAST(life_expectancy AS REAL) < 70 THEN 'Low'
		WHEN 70 <= CAST(life_expectancy AS REAL) AND CAST(life_expectancy AS REAL) < 80 THEN 'Normal'
		ELSE 'High'
		END) AS life_expectancy_category
	FROM so_table
	)

-- SELECT * FROM sole_table

SELECT life_expectancy_category,
	-- ROUND(AVG(CAST(total_cases AS REAL) / CAST(population AS REAL)) * 100, 2) AS avg_variable_per_population
	-- ROUND(AVG(CAST(total_deaths AS REAL) / CAST(population AS REAL)) * 100, 2) AS avg_variable_per_population
	-- ROUND(AVG(CAST(people_vaccinated AS REAL) / CAST(population AS REAL)) * 100, 2) AS avg_variable_per_population	
	ROUND(AVG(CAST(people_fully_vaccinated AS REAL) / CAST(population AS REAL)) * 100, 2) AS avg_variable_per_population	
FROM sole_table
GROUP BY life_expectancy_category
ORDER BY avg_variable_per_population DESC

-- Life expectancy & COVID-19 cases
-- Very intriguinly, the higher the life expectancy, the higher cases per population. 
-- A possible explanation could be that higher life expectancy countries are generally richer and therefore,
-- its population tends to travel more, increasing the risk of catching the virus abroad and bringing it home

-- Life expectancy & COVID-19 deaths
-- Following the relationship between life expectancy & COVID-19 cases, higher life expectancy has as a result
-- higher COVID-19 deaths

-- Life expectancy & COVID-19 vaccinations
-- In the Economic development by country section we concluded that economic strenght only impact on COVID-19 is
-- found in vaccinations. If we accept that life expectancy increases with economic strenght, we can get to the
-- conclusion that countries with higher life expectancy should present higher vaccunations per population.
-- Data corroborates this assessment

-- 3.2.2. Handwashing facilities and COVID-19

-- Creating the table

WITH so_table AS
	(
	SELECT so.location,
		so.continent,
		so.population,
		so.population_density,
		so.median_age,
		so.handwashing_facilities,
		so.life_expectancy,
		de.total_cases,
		de.total_deaths,
		va.people_vaccinated,
		va.people_fully_vaccinated
FROM PortfolioProject..socioeconomics AS so
INNER JOIN PortfolioProject..deaths AS de
ON so.location = de.location AND so.date = de.date
INNER JOIN PortfolioProject..vaccinations AS va
ON so.location = va.location AND so.date = va.date
WHERE so.continent IS NOT NULL 
	AND de.total_cases IS NOT NULL
	AND so.date IN
		(SELECT MAX(date)
		FROM PortfolioProject..socioeconomics)
	)

-- SELECT * FROM so_table

SELECT location,
	REPLACE(FORMAT(CAST(handwashing_facilities AS REAL), 'N', 'de-de'), ',00', '') AS handwashing_facilities,
	-- ROUND((CAST(total_cases AS REAL) / CAST(population AS REAL)* 100), 2) AS variable
	-- ROUND((CAST(total_deaths AS REAL) / CAST(population AS REAL)* 100), 2) AS variable
	-- ROUND((CAST(people_vaccinated AS REAL) / CAST(population AS REAL)) * 100, 2) AS variable
	ROUND((CAST(people_fully_vaccinated AS REAL) / CAST(population AS REAL)) * 100, 2) AS variable
FROM so_table
WHERE handwashing_facilities IS NOT NULL
	-- AND people_vaccinated IS NOT NULL
	AND people_fully_vaccinated IS NOT NULL
ORDER BY variable DESC

-- There is no direct relationship between a country handwashing facilities and its COVID-19 cases and deaths
-- Regarding vaccinations, there are so many NULL cases that we cannot arrive to a conclusion


-- 3.2.3. Median age and COVID-19

-- Creating the table

WITH so_table AS
	(
	SELECT so.location,
		so.continent,
		so.population,
		so.population_density,
		ROUND(so.median_age, 0) AS median_age,
		so.handwashing_facilities,
		so.life_expectancy,
		de.total_cases,
		de.total_deaths,
		va.people_vaccinated,
		va.people_fully_vaccinated
FROM PortfolioProject..socioeconomics AS so
INNER JOIN PortfolioProject..deaths AS de
ON so.location = de.location AND so.date = de.date
INNER JOIN PortfolioProject..vaccinations AS va
ON so.location = va.location AND so.date = va.date
WHERE so.continent IS NOT NULL 
	AND de.total_cases IS NOT NULL
	AND so.date IN
		(SELECT MAX(date)
		FROM PortfolioProject..socioeconomics)
	)

--SELECT location,
--	median_age,
--	ROUND(CAST(total_cases AS REAL) / CAST(population AS REAL) * 100, 2) AS variable
--FROM so_table
--WHERE median_age IS NOT NULL
--ORDER BY variable DESC

-- From a first look it seems as if lower median age results in lower cases per population

--SELECT median_age,
--	ROUND(AVG(CAST(total_cases AS REAL) / CAST(population AS REAL) * 100), 2) AS variable
--FROM so_table
--WHERE median_age IS NOT NULL
--GROUP BY median_age
--ORDER BY median_age DESC

-- As we suspected, total cases per population are significantly lower for younger median age countries
-- Lets analyze further. Which countries present lower median ages?

--SELECT continent,
--	location,
--	median_age
--FROM so_table
--WHERE median_age IS NOT NULL
--ORDER BY median_age ASC

-- Not surprisingly, Africa presents most younger populations while developed countries have elder 

--SELECT continent,
--	ROUND(AVG(median_age), 2) AS avg_median_age
--FROM so_table
--WHERE median_age IS NOT NULL
--GROUP BY continent
--ORDER BY avg_median_age

-- Lets save this result into a table

WITH so_table AS
	(
	SELECT so.location,
		so.continent,
		so.population,
		so.population_density,
		ROUND(so.median_age, 0) AS median_age,
		so.handwashing_facilities,
		so.life_expectancy,
		de.total_cases,
		de.total_deaths,
		va.people_vaccinated,
		va.people_fully_vaccinated
FROM PortfolioProject..socioeconomics AS so
INNER JOIN PortfolioProject..deaths AS de
ON so.location = de.location AND so.date = de.date
INNER JOIN PortfolioProject..vaccinations AS va
ON so.location = va.location AND so.date = va.date
WHERE so.continent IS NOT NULL 
	AND de.total_cases IS NOT NULL
	AND so.date IN
		(SELECT MAX(date)
		FROM PortfolioProject..socioeconomics)
	),

continent_median_age AS
	(
	SELECT continent,
		ROUND(AVG(median_age), 2) AS avg_median_age
	FROM so_table
	WHERE median_age IS NOT NULL
	GROUP BY continent
	),

continent_cases AS
	(SELECT continent,
		ROUND(AVG(CAST(total_cases AS REAL) / CAST(population AS REAL)) * 100, 2) AS avg_cases
	FROM so_table
	GROUP BY continent
	)

-- Finally, lets compare each continent median age with its cases per pupulation

SELECT continent_median_age.continent,
	continent_median_age.avg_median_age,
	continent_cases.avg_cases
FROM continent_median_age
INNER JOIN continent_cases ON continent_median_age.continent = continent_cases.continent
ORDER BY avg_cases ASC

-- We have gotten at a most peculiar result. The two continents with lower average median age (Africa and Oceania)
-- present the lowest average cases per population. What is more, the higher average median age continent (Europe)
-- presents the highes average cases. Of course, it is not my intention to imply there is a correlation between
-- a country median age and its cases per population.

-- Africa and Oceania relatively few COVID-19 cases surely obey other factors, such as less interchange of people with
-- other regions such as Europe and Asia.



