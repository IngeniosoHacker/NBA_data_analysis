-- Final query with team names
WITH team_stats AS (
    -- Home games
    SELECT 
        SEASON,
        TEAM_ID_HOME as TEAM_ID,
        PTS_HOME as points_scored,
        PTS_AWAY as points_allowed
    FROM Game 
    WHERE PTS_HOME IS NOT NULL AND PTS_AWAY IS NOT NULL
    
    UNION ALL
    
    -- Away games  
    SELECT 
        SEASON,
        TEAM_ID_AWAY as TEAM_ID,
        PTS_AWAY as points_scored,
        PTS_HOME as points_allowed
    FROM Game 
    WHERE PTS_HOME IS NOT NULL AND PTS_AWAY IS NOT NULL
)
SELECT 
    ts.SEASON,
    ts.TEAM_ID,
    ta.NICKNAME, 
    ROUND(AVG(ts.points_scored), 1) as avg_points_scored,
    ROUND(AVG(ts.points_allowed), 1) as avg_points_allowed,
    COUNT(*) as games_played
FROM team_stats ts
LEFT JOIN Team_Attributes ta ON ts.TEAM_ID = ta.ID
GROUP BY ts.SEASON, ts.TEAM_ID, ta.NICKNAME
ORDER BY ts.SEASON, ts.TEAM_ID;
