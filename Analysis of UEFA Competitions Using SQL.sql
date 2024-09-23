-- creates tables 
-- gols table 
create table golas(
	GOAL_ID    
 varchar(20),    
MATCH_ID    
 varchar(20),    
 PID         
 varchar(20),    
 DURATION    
 Integer,   
 ASSIST      
 varchar(100),      
 GOAL_DESC   
 varchar(20));

-- gols matches
create table matches(
    MATCH_ID VARCHAR(50) PRIMARY KEY,      
    SEASON VARCHAR(20),                     
    DATE VARCHAR(10),                      
    HOME_TEAM VARCHAR(100),                 
    AWAY_TEAM VARCHAR(100),                 
    STADIUM VARCHAR(100),                  
    HOME_TEAM_SCORE INT,                    
    AWAY_TEAM_SCORE INT,                    
    PENALTY_SHOOT_OUT INT,                 
    ATTENDANCE INT
);

-- Table players
CREATE TABLE players (
    PLAYER_ID VARCHAR(50) PRIMARY KEY,
    FIRST_NAME VARCHAR(50),
    LAST_NAME VARCHAR(50),
    NATIONALITY VARCHAR(50),
    DOB DATE,
    TEAM VARCHAR(100),
    JERSEY_NUMBER FLOAT,
    POSITION VARCHAR(50),
    HEIGHT FLOAT,
    WEIGHT FLOAT,
    FOOT VARCHAR(1)
);

-- Table stadiums
CREATE TABLE stadiums (
    Name VARCHAR(100),
    City VARCHAR(100),
    Country VARCHAR(100),
    Capacity INT
);

/* For load data into these table just right click on table select import/export option and
and select your file path and enter ok */




--1)Count the Total Number of Teams
select count(distinct team_name) as total_number_of_teams from teams;

--2)Find the Number of Teams per Country
select count(*) as num_of_teams,country from teams
group by country;

--3)Calculate the Average Team Name Length
select avg(length(team_name)) as avg_team_name from teams;

--4)Calculate the Average Stadium Capacity in Each Country round it off and sort by the total stadiums in the country.

SELECT 
    country, 
    ROUND(AVG(capacity)) AS average_capacity,
    COUNT(*) AS total_stadiums
FROM 
    stadiums
GROUP BY 
    country
ORDER BY 
    total_stadiums ;

--5)Calculate the Total Goals Scored.
select count(goal_id) as total_goals from goals;

--6)Find the total teams that have city in their names
SELECT COUNT(*) AS total_teams_with_city
FROM teams
WHERE lower(team_name) LIKE '%city%'; 

--7) Use Text Functions to Concatenate the Team's Name and Country
select concat(team_name,' ',country) as team_and_country from teams;

/*8) What is the highest attendance recorded in the dataset, and which match 
(including home and away teams, and date) does it correspond to?*/
select home_team,away_team,date,attendance from matches
where attendance = (select max(attendance) from matches);

/*9)What is the lowest attendance recorded in the dataset, and which match
(including home and away teams, and date)does it correspond to set
the criteria as greater than 1 as some matches had 0 attendance because of covid.*/
select home_team,away_team,date,attendance from matches
where attendance = (select min(attendance) from matches
	where attendance > 1);

/*10) Identify the match with the highest total score (sum of home and away team scores) in the dataset.
Include the match ID, home and away teams, and the total score.*/

SELECT 
    match_id, 
    home_team, 
    away_team, 
    (home_team_score + away_team_score) AS total_score
FROM 
    matches
ORDER BY 
    total_score DESC
LIMIT 1;

/*11)Find the total goals scored by each team, distinguishing between home and away goals.
Use a CASE WHEN statement to differentiate home and away goals within the subquery */
SELECT 
    team,
    SUM(home_team_score) AS home_team_score,
    SUM(away_team_score) AS total_away_score,
    SUM(home_team_score + away_team_score) AS total_score
FROM (
    SELECT
        home_team AS team,
        home_team_score,
        CASE WHEN away_team = away_team THEN away_team_score ELSE 0 END AS away_team_score
    FROM matches
    UNION ALL
    SELECT
        away_team AS team,
        CASE WHEN home_team = home_team THEN home_team_score ELSE 0 END AS home_team_score,
        away_team_score
    FROM matches
) AS combined_score
GROUP BY team
ORDER BY total_score DESC;

/*12) windows function - Rank teams based on their total scored goals (home and away combined)
using a window function.In the stadium Old Trafford.*/

WITH team_goals AS (
    SELECT
        TEAM,
        SUM(total_goals) AS total_goals
    FROM (
        SELECT
            HOME_TEAM AS TEAM,
            SUM(HOME_TEAM_SCORE) AS total_goals
        FROM
            matches
        WHERE
            lower(STADIUM) = 'old trafford'
        GROUP BY
            HOME_TEAM

        UNION ALL

        SELECT
            AWAY_TEAM AS TEAM,
            SUM(AWAY_TEAM_SCORE) AS total_goals
        FROM
            matches
        WHERE
            lower(STADIUM) = 'old trafford'
        GROUP BY
            AWAY_TEAM
    ) AS combined_goals
    GROUP BY
        TEAM
)
SELECT
    TEAM,
    total_goals,
    RANK() OVER (ORDER BY total_goals DESC) AS team_rank
FROM
    team_goals
ORDER BY
    team_rank;



/*13) TOP 5  players who scored the most goals in Old Trafford, ensuring null values are not included
in the result (especially pertinent for cases where a player might not have scored any goals).*/
WITH player_goals AS (
    SELECT
        g.PID AS player_id,
        p.FIRST_NAME || ' ' || p.LAST_NAME AS player_name,
        COUNT(g.GOAL_ID) AS total_goals
    FROM
        goals g
    JOIN
        matches m ON g.MATCH_ID = m.MATCH_ID
    JOIN
        players p ON g.PID = p.PLAYER_ID
    WHERE
        lower(m.STADIUM) = 'old trafford'
    GROUP BY
        g.PID, p.FIRST_NAME, p.LAST_NAME
)
SELECT
    player_id,
    player_name,
    total_goals
FROM
    player_goals
WHERE
    total_goals > 0
ORDER BY
    total_goals DESC
LIMIT 5;


/*14)Write a query to list all players along with the total number of goals they have scored.
Order the results by the number of goals scored in descending order to easily identify the top 6 scorers.*/

select pl.first_name,pl.last_name,count(gl.goal_id) as total_goals from goals gl
inner join players pl
on pl.player_id = gl.pid
group by pl.first_name,pl.last_name
order by total_goals desc
	limit 6;

/*15)Identify the Top Scorer for Each Team - Find the player from each team who has scored the most goals
in all matches combined. This question requires joining the Players, Goals, and possibly the Matches tables,
and then using a subquery to aggregate goals by players and teams.*/

select 
    pl.team,
    pl.player_id,
    pl.first_name || ' ' || pl.last_name AS player_name,
    count(gl.goal_id) as total_goals
from  
    goals gl
inner join 
    players pl on gl.pid = pl.player_id
inner join 
    matches mat on gl.match_id = mat.match_id
group by 
    pl.team, pl.player_id, player_name
having 
    count(gl.goal_id) = (
        select 
            max(player_goals)
        from 
            (select 
                pl2.team,
                pl2.player_id,
                COUNT(gl2.goal_id) AS player_goals
            FROM 
                goals gl2
            inner join 
                players pl2 ON gl2.pid = pl2.player_id
            group by 
                pl2.team, pl2.player_id
            ) as team_top_scorer
        where 
            team_top_scorer.team = pl.team
    )
ORDER BY 
    pl.team;


/*16)Find the Total Number of Goals Scored in the Latest Season
- Calculate the total number of goals scored in the latest season available in the dataset.
	This question involves using a subquery to first identify the latest season from the Matches table,
	then summing the goals from the Goals table that occurred in matches from that season.*/

select 
    count(gl.goal_id) AS total_goals,mat.season
from 
    goals gl
inner join 
    matches mat
	on gl.match_id = mat.match_id
where 
    mat.season = (
        select 
            max(season)
        from 
            matches
    )
group by mat.season
	;

/*17)Find Matches with Above Average Attendance - Retrieve a list of matches that had an attendance higher
than the average attendance across all matches. This question requires a subquery to calculate the average
	attendance first, then use it to filter matches.*/
select * from matches;
SELECT 
    match_id,
    season,
    date,
    home_team,
    away_team,
    stadium,
    home_team_score,
    away_team_score,
    penalty_shoot_out,
    attendance
FROM 
    matches
WHERE 
    attendance > (
        SELECT 
            AVG(attendance)
        FROM 
            matches
    );



/*18)Find the Number of Matches Played Each Month - Count how many matches were played in each month across
all seasons. This question requires extracting the month from the match dates and grouping the results
by this value. as January Feb march */

SELECT 
    TO_CHAR(TO_DATE(date, 'DD-MM-YYYY'), 'Month') AS month,
    COUNT(*) AS match_count
FROM 
    matches
GROUP BY 
    TO_CHAR(TO_DATE(date, 'DD-MM-YYYY'), 'Month'),
    TO_CHAR(TO_DATE(date, 'DD-MM-YYYY'), 'MM')
ORDER BY 
    TO_CHAR(TO_DATE(date, 'DD-MM-YYYY'), 'MM');


 