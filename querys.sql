-- Query 3: Top 5 referees where visiting team loses most

SELECT 
    CONCAT(go.FIRST_NAME, ' ', go.LAST_NAME) as referee_name,
    COUNT(*) as total_games_officiated,
    SUM(CASE WHEN g.WL_AWAY = 'L' THEN 1 ELSE 0 END) as away_team_losses,
    ROUND(SUM(CASE WHEN g.WL_AWAY = 'L' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as away_loss_percentage
FROM Game_Officials go
JOIN Game g ON go.GAME_ID = g.GAME_ID
WHERE g.WL_AWAY IS NOT NULL
GROUP BY go.OFFICIAL_ID, go.FIRST_NAME, go.LAST_NAME
HAVING COUNT(*) >= 50  -- Only referees with at least 50 games
ORDER BY away_loss_percentage DESC
LIMIT 5;

-- Query 4: Team with highest salaries vs most valuable players

-- Part A: Teams with highest total salaries (most recent season)
WITH recent_season AS (
    SELECT MAX(slugSeason) as latest_season FROM Player_Salary
),
team_salaries AS (
    SELECT 
        ps.nameTeam,
        SUM(ps.value) as total_salary,
        COUNT(*) as player_count,
        AVG(ps.value) as avg_salary
    FROM Player_Salary ps
    CROSS JOIN recent_season rs
    WHERE ps.slugSeason = rs.latest_season 
      AND ps.isOnRoster = true
      AND ps.value IS NOT NULL
    GROUP BY ps.nameTeam
)
SELECT 
    nameTeam,
    ROUND(total_salary, 2) as total_salary,
    player_count,
    ROUND(avg_salary, 2) as avg_salary
FROM team_salaries
ORDER BY total_salary DESC
LIMIT 5;

-- Part B: Most valuable players by team (based on PIE - Player Impact Estimate)
WITH team_player_value AS (
    SELECT 
        pa.TEAM_NAME,
        AVG(pa.PIE) as avg_player_value,
        SUM(pa.PIE) as total_player_value,
        COUNT(*) as active_players
    FROM Player_Attributes pa
    WHERE pa.PIE IS NOT NULL 
      AND pa.ROSTERSTATUS = 'Active'
    GROUP BY pa.TEAM_NAME
)
SELECT 
    TEAM_NAME,
    ROUND(avg_player_value, 3) as avg_player_value,
    ROUND(total_player_value, 3) as total_player_value,
    active_players
FROM team_player_value
ORDER BY total_player_value DESC
LIMIT 5;

-- Part C: Compare salary vs player value
WITH recent_season AS (
    SELECT MAX(slugSeason) as latest_season FROM Player_Salary
),
team_salaries AS (
    SELECT 
        ps.nameTeam,
        SUM(ps.value) as total_salary
    FROM Player_Salary ps
    CROSS JOIN recent_season rs
    WHERE ps.slugSeason = rs.latest_season 
      AND ps.isOnRoster = true
      AND ps.value IS NOT NULL
    GROUP BY ps.nameTeam
),
team_values AS (
    SELECT 
        pa.TEAM_NAME,
        AVG(pa.PIE) as avg_player_value
    FROM Player_Attributes pa
    WHERE pa.PIE IS NOT NULL 
      AND pa.ROSTERSTATUS = 'Active'
    GROUP BY pa.TEAM_NAME
)
SELECT 
    ts.nameTeam,
    ROUND(ts.total_salary, 0) as total_salary,
    ROUND(tv.avg_player_value, 3) as avg_player_value,
    CASE 
        WHEN tv.avg_player_value > 0 THEN ROUND(ts.total_salary / tv.avg_player_value, 0)
        ELSE NULL 
    END as salary_to_value_ratio
FROM team_salaries ts
JOIN team_values tv ON ts.nameTeam = tv.TEAM_NAME
ORDER BY salary_to_value_ratio ASC  -- Lower ratio = better value
LIMIT 10;

-- Query 5: Season with most games and longest duration

-- Season with most games in NBA history
SELECT 
    SEASON,
    COUNT(*) as total_games,
    COUNT(DISTINCT TEAM_ID_HOME) as unique_teams,
    MIN(GAME_DATE) as season_start,
    MAX(GAME_DATE) as season_end,
    (MAX(GAME_DATE) - MIN(GAME_DATE)) as season_duration_days
FROM Game 
GROUP BY SEASON
ORDER BY total_games DESC
LIMIT 1;

-- Season that lasted longest (by date range)
SELECT 
    SEASON,
    MIN(GAME_DATE) as season_start,
    MAX(GAME_DATE) as season_end,
    (MAX(GAME_DATE) - MIN(GAME_DATE)) as season_duration_days,
    COUNT(*) as total_games
FROM Game 
GROUP BY SEASON
ORDER BY season_duration_days DESC
LIMIT 1;

-- All seasons ranked by games and duration
SELECT 
    SEASON,
    COUNT(*) as total_games,
    MIN(GAME_DATE) as season_start,
    MAX(GAME_DATE) as season_end,
    (MAX(GAME_DATE) - MIN(GAME_DATE)) as season_duration_days
FROM Game 
GROUP BY SEASON
ORDER BY total_games DESC, season_duration_days DESC;

-- Query 6: Team with best point differential - 2017 and 2018 seasons

-- Point differential for 2017 season
WITH team_stats_2017 AS (
    -- Home games
    SELECT 
        TEAM_ID_HOME as TEAM_ID,
        TEAM_NAME_HOME as TEAM_NAME,
        (PTS_HOME - PTS_AWAY) as point_differential
    FROM Game 
    WHERE SEASON = '2017' AND PTS_HOME IS NOT NULL AND PTS_AWAY IS NOT NULL
    
    UNION ALL
    
    -- Away games
    SELECT 
        TEAM_ID_AWAY as TEAM_ID,
        TEAM_NAME_AWAY as TEAM_NAME,
        (PTS_AWAY - PTS_HOME) as point_differential
    FROM Game 
    WHERE SEASON = '2017' AND PTS_HOME IS NOT NULL AND PTS_AWAY IS NOT NULL
)
SELECT 
    '2017' as season,
    TEAM_ID,
    TEAM_NAME,
    ROUND(AVG(point_differential), 2) as avg_point_differential,
    COUNT(*) as games_played
FROM team_stats_2017
GROUP BY TEAM_ID, TEAM_NAME
ORDER BY avg_point_differential DESC
LIMIT 1;

-- Point differential for 2018 season
WITH team_stats_2018 AS (
    -- Home games
    SELECT 
        TEAM_ID_HOME as TEAM_ID,
        TEAM_NAME_HOME as TEAM_NAME,
        (PTS_HOME - PTS_AWAY) as point_differential
    FROM Game 
    WHERE SEASON = '2018' AND PTS_HOME IS NOT NULL AND PTS_AWAY IS NOT NULL
    
    UNION ALL
    
    -- Away games
    SELECT 
        TEAM_ID_AWAY as TEAM_ID,
        TEAM_NAME_AWAY as TEAM_NAME,
        (PTS_AWAY - PTS_HOME) as point_differential
    FROM Game 
    WHERE SEASON = '2018' AND PTS_HOME IS NOT NULL AND PTS_AWAY IS NOT NULL
)
SELECT 
    '2018' as season,
    TEAM_ID,
    TEAM_NAME,
    ROUND(AVG(point_differential), 2) as avg_point_differential,
    COUNT(*) as games_played
FROM team_stats_2018
GROUP BY TEAM_ID, TEAM_NAME
ORDER BY avg_point_differential DESC
LIMIT 1;

-- Query 7: Most valuable player from 2018 draft

-- Most valuable player from 2018 draft (based on current PIE value)
SELECT 
    d.namePlayer,
    d.numberPickOverall as draft_position,
    d.numberRound as draft_round,
    d.nameTeam as drafted_by_team,
    pa.TEAM_NAME as current_team,
    pa.PIE as current_value_pie,
    pa.PTS as current_avg_points,
    pa.AST as current_avg_assists,
    pa.REB as current_avg_rebounds,
    pa.ALL_STAR_APPEARANCES
FROM Draft d
LEFT JOIN Player_Attributes pa ON d.idPlayer = pa.ID
WHERE d.yearDraft = 2018
  AND pa.PIE IS NOT NULL
ORDER BY pa.PIE DESC
LIMIT 1;

-- Top 5 most valuable players from 2018 draft
SELECT 
    d.namePlayer,
    d.numberPickOverall as draft_position,
    d.numberRound as draft_round,
    d.nameTeam as drafted_by_team,
    pa.TEAM_NAME as current_team,
    pa.PIE as current_value_pie,
    pa.PTS as current_avg_points,
    pa.ALL_STAR_APPEARANCES
FROM Draft d
LEFT JOIN Player_Attributes pa ON d.idPlayer = pa.ID
WHERE d.yearDraft = 2018
  AND pa.PIE IS NOT NULL
ORDER BY pa.PIE DESC
LIMIT 5;

-- Query 8: Top 5 states with highest salary payments (2020-2022)

-- Extract state from team city and calculate salary payments
WITH state_mapping AS (
    SELECT DISTINCT
        ta.CITY,
        CASE 
            -- Major NBA cities to states mapping
            WHEN ta.CITY = 'Los Angeles' THEN 'California'
            WHEN ta.CITY = 'Golden State' THEN 'California' 
            WHEN ta.CITY = 'Sacramento' THEN 'California'
            WHEN ta.CITY = 'San Antonio' THEN 'Texas'
            WHEN ta.CITY = 'Dallas' THEN 'Texas'
            WHEN ta.CITY = 'Houston' THEN 'Texas'
            WHEN ta.CITY = 'Miami' THEN 'Florida'
            WHEN ta.CITY = 'Orlando' THEN 'Florida'
            WHEN ta.CITY = 'New York' THEN 'New York'
            WHEN ta.CITY = 'Brooklyn' THEN 'New York'
            WHEN ta.CITY = 'Chicago' THEN 'Illinois'
            WHEN ta.CITY = 'Boston' THEN 'Massachusetts'
            WHEN ta.CITY = 'Philadelphia' THEN 'Pennsylvania'
            WHEN ta.CITY = 'Detroit' THEN 'Michigan'
            WHEN ta.CITY = 'Atlanta' THEN 'Georgia'
            WHEN ta.CITY = 'Washington' THEN 'D.C.'
            WHEN ta.CITY = 'Charlotte' THEN 'North Carolina'
            WHEN ta.CITY = 'Milwaukee' THEN 'Wisconsin'
            WHEN ta.CITY = 'Indiana' THEN 'Indiana'
            WHEN ta.CITY = 'Cleveland' THEN 'Ohio'
            WHEN ta.CITY = 'Toronto' THEN 'Ontario'
            WHEN ta.CITY = 'Denver' THEN 'Colorado'
            WHEN ta.CITY = 'Utah' THEN 'Utah'
            WHEN ta.CITY = 'Oklahoma City' THEN 'Oklahoma'
            WHEN ta.CITY = 'Portland' THEN 'Oregon'
            WHEN ta.CITY = 'Seattle' THEN 'Washington'
            WHEN ta.CITY = 'Minnesota' THEN 'Minnesota'
            WHEN ta.CITY = 'New Orleans' THEN 'Louisiana'
            WHEN ta.CITY = 'Memphis' THEN 'Tennessee'
            WHEN ta.CITY = 'Phoenix' THEN 'Arizona'
            ELSE ta.CITY
        END as state
    FROM Team_Attributes ta
),
state_salaries AS (
    SELECT 
        sm.state,
        SUM(ps.value) as total_salary_paid,
        COUNT(DISTINCT ps.namePlayer) as total_players,
        AVG(ps.value) as avg_salary
    FROM Player_Salary ps
    JOIN state_mapping sm ON ps.nameTeam LIKE '%' || sm.CITY || '%'
    WHERE ps.slugSeason IN ('2020-21', '2021-22')
      AND ps.isOnRoster = true
      AND ps.value IS NOT NULL
    GROUP BY sm.state
)
SELECT 
    state,
    ROUND(total_salary_paid, 0) as total_salary_paid,
    total_players,
    ROUND(avg_salary, 0) as avg_salary_per_player
FROM state_salaries
WHERE state IS NOT NULL
ORDER BY total_salary_paid DESC
LIMIT 5;

-- Alternative approach using team names directly
WITH team_state_salaries AS (
    SELECT 
        CASE 
            WHEN ps.nameTeam LIKE '%Lakers%' OR ps.nameTeam LIKE '%Clippers%' 
                 OR ps.nameTeam LIKE '%Warriors%' OR ps.nameTeam LIKE '%Kings%' THEN 'California'
            WHEN ps.nameTeam LIKE '%Spurs%' OR ps.nameTeam LIKE '%Mavericks%' 
                 OR ps.nameTeam LIKE '%Rockets%' THEN 'Texas'
            WHEN ps.nameTeam LIKE '%Heat%' OR ps.nameTeam LIKE '%Magic%' THEN 'Florida'
            WHEN ps.nameTeam LIKE '%Knicks%' OR ps.nameTeam LIKE '%Nets%' THEN 'New York'
            WHEN ps.nameTeam LIKE '%Bulls%' THEN 'Illinois'
            WHEN ps.nameTeam LIKE '%Celtics%' THEN 'Massachusetts'
            ELSE 'Other'
        END as state,
        SUM(ps.value) as total_salary
    FROM Player_Salary ps
    WHERE ps.slugSeason IN ('2020-21', '2021-22')
      AND ps.isOnRoster = true
      AND ps.value IS NOT NULL
    GROUP BY 
        CASE 
            WHEN ps.nameTeam LIKE '%Lakers%' OR ps.nameTeam LIKE '%Clippers%' 
                 OR ps.nameTeam LIKE '%Warriors%' OR ps.nameTeam LIKE '%Kings%' THEN 'California'
            WHEN ps.nameTeam LIKE '%Spurs%' OR ps.nameTeam LIKE '%Mavericks%' 
                 OR ps.nameTeam LIKE '%Rockets%' THEN 'Texas'
            WHEN ps.nameTeam LIKE '%Heat%' OR ps.nameTeam LIKE '%Magic%' THEN 'Florida'
            WHEN ps.nameTeam LIKE '%Knicks%' OR ps.nameTeam LIKE '%Nets%' THEN 'New York'
            WHEN ps.nameTeam LIKE '%Bulls%' THEN 'Illinois'
            WHEN ps.nameTeam LIKE '%Celtics%' THEN 'Massachusetts'
            ELSE 'Other'
        END
)
SELECT 
    state,
    ROUND(total_salary, 0) as total_salary_paid
FROM team_state_salaries
WHERE state != 'Other'
ORDER BY total_salary DESC
LIMIT 5;
