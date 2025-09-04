# NBA Data Analysis


## Data cleaning

WE found a problem in the `Player_Attributes.csv` file, cause the 4th column `DISPLAY_FIRST_LAST` had a comma inside the value, so it was breaking the whole csv structure. To fix this problem, we use `sed` command:

```
sed -E 's/"([^,]+), ([^"]+)"/"\1 \2"/g' Player_Attributes.csv > Player_Attributes_clean.csv
```
Bassically: 

`[^,]+`: One or more characters that aren't commas
`[^"]+`: One or more characters that aren't quotes

This transforms:

"John, Doe" → "John Doe"

## Database Setup

The database is on Docker, so we use the `docker cp` command to copy al the `csv` files into the container. Inside the container we use `psql` to run the `setup.sql` file.
This file contains the querys to create the tables. But also contains the `COPY` function to copy the csv data into the database.

## Questions

1.1. Who is the taller active Player?

- Query:

```
SELECT p.full_name, pa.height
FROM player p
JOIN player_attributes pa ON p.id = pa.id
WHERE p.is_active = TRUE
ORDER BY pa.height DESC
LIMIT 1;
```

Answer:

```
 full_name  | height
------------+--------
 Tacko Fall | 89.0
(1 row)

```

1.2.  Who is the shorter active Player?


```
SELECT p.full_name, pa.height
FROM player p
JOIN player_attributes pa ON p.id = pa.id
WHERE p.is_active = TRUE
ORDER BY pa.height ASC
LIMIT 1;
```

Answer:

```
  full_name   | height
---------------+--------
 Chris Clemons | 69.0
(1 row)

```

2. What was the average points scored and conceded by each team in each of the relevant seasons?
```
WITH base AS (
  SELECT
    g.season,
    g.team_abbreviation_home AS team_abbr,
    g.team_name_home         AS team_name,
    NULLIF(regexp_replace(COALESCE(g.pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric  AS pts_for,
    NULLIF(regexp_replace(COALESCE(g.pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric  AS pts_against
  FROM game g
  UNION ALL
  SELECT
    g.season,
    g.team_abbreviation_away,
    g.team_name_away,
    NULLIF(regexp_replace(COALESCE(g.pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric,
    NULLIF(regexp_replace(COALESCE(g.pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric
  FROM game g
)
SELECT
  season,
  team_abbr,
  team_name,
  AVG(pts_for)     AS avg_pts_for,
  AVG(pts_against) AS avg_pts_against
FROM base
GROUP BY season, team_abbr, team_name
ORDER BY season, team_abbr;
```
Answer: Demasiado largo para poner aquí

3) Top 5 árbitros en cuyos juegos el visitante pierde
```
SELECT
  CONCAT(go.first_name,' ',go.last_name) AS official,
  COUNT(*) AS away_losses
FROM game_officials go
JOIN game g ON g.game_id = go.game_id
WHERE UPPER(g.wl_away) = 'L'
GROUP BY official
ORDER BY away_losses DESC
LIMIT 5;
```

Answer: 
```
Resultado:
"Tom Washington"	693
"James Capers"	687
"Scott Foster"	678
"Ed Malloy"	676
"Pat Fraher"	667
```

4) Equipo con salarios más altos actualmente + comparación con “jugadores más valiosos” (por salario)
4.a) Equipo con mayor masa salarial en la temporada más reciente
```
WITH latest AS (SELECT MAX(slugseason) AS slugseason FROM player_salary),
clean AS (
  SELECT
    ps.slugseason,
    ps.nameteam AS team,
    NULLIF(regexp_replace(COALESCE(ps.value::text,''),'[^0-9.\-]','','g'),'')::numeric AS salary
  FROM player_salary ps
  JOIN latest l ON ps.slugseason = l.slugseason
)
SELECT slugseason, team, SUM(salary) AS total_salary
FROM clean
GROUP BY slugseason, team
ORDER BY total_salary DESC
LIMIT 1;
```

Answer:
```
Resultado: 
"2024-25"	"Milwaukee Bucks"	87291330.0
```

4.b) Top 10 jugadores mejor pagados en esa temporada
```
WITH latest AS (SELECT MAX(slugseason) AS slugseason FROM player_salary)
SELECT
  ps.slugseason,
  ps.nameplayer,
  ps.nameteam AS team,
  NULLIF(regexp_replace(COALESCE(ps.value::text,''),'[^0-9.\-]','','g'),'')::numeric AS salary
FROM player_salary ps
JOIN latest l ON ps.slugseason = l.slugseason
ORDER BY salary DESC NULLS LAST
LIMIT 10;
```

Answer: 
```
"2024-25"	"Giannis Antetokounmpo"	"Milwaukee Bucks"	48787676.0
"2024-25"	"Damian Lillard"	"Portland Trail Blazers"	48787676.0
"2024-25"	"Paul George"	"Los Angeles Clippers"	48787676.0
"2024-25"	"Rudy Gobert"	"Utah Jazz"	43827586.0
"2024-25"	"Anthony Davis"	"Los Angeles Lakers"	43219440.0
"2024-25"	"Ben Simmons"	"Philadelphia 76ers"	40338144.0
"2024-25"	"Jrue Holiday"	"Milwaukee Bucks"	38503654.0
"2024-25"	"Jamal Murray"	"Denver Nuggets"	36016200.0
"2024-25"	"Brandon Ingram"	"New Orleans Pelicans"	36016200.0
"2024-25"	"Bam Adebayo"	"Miami Heat"	34848340.0
```

4.c) ¿Hay relación entre masa salarial y tener “top paid players”?
```
WITH latest AS (SELECT MAX(slugseason) AS slugseason FROM player_salary),
clean AS (
  SELECT ps.nameteam AS team,
         NULLIF(regexp_replace(COALESCE(ps.value::text,''),'[^0-9.\-]','','g'),'')::numeric AS salary
  FROM player_salary ps JOIN latest l ON ps.slugseason = l.slugseason
),
team_payroll AS (
  SELECT team, SUM(salary) AS total_salary
  FROM clean GROUP BY team
),
top_players AS (
  SELECT team, salary
  FROM clean
  ORDER BY salary DESC NULLS LAST
  LIMIT 10
)
SELECT tp.team,
       tp.total_salary,
       COUNT(tpl.salary) AS top_paid_players_in_team
FROM team_payroll tp
LEFT JOIN top_players tpl ON tpl.team = tp.team
GROUP BY tp.team, tp.total_salary
ORDER BY tp.total_salary DESC;
```

Answer: DEMASIADO LARGO PARA PONER AQUÍ

5) a) Temporada con más partidos
```
SELECT season, COUNT(*) AS games
FROM game
GROUP BY season
ORDER BY games DESC
LIMIT 1;
```

Respuesta: 
```
2013	1286
```

b) Temporada más larga en fechas
```
SELECT season,
       (MAX(COALESCE(NULLIF(game_date,'')::date, NULLIF(game_date_est,'')::date))
      - MIN(COALESCE(NULLIF(game_date,'')::date, NULLIF(game_date_est,'')::date))) AS days_span
FROM game
GROUP BY season
ORDER BY days_span DESC
LIMIT 1;
```

Respuesta: 
```
2019	297
```

6) Equipo con mayor diferencial promedio por partido — 2017 y 2018
```
WITH base AS (
  SELECT
    g.season,
    g.team_abbreviation_home AS team_abbr,
    g.team_name_home         AS team_name,
    ( NULLIF(regexp_replace(COALESCE(g.pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric
    - NULLIF(regexp_replace(COALESCE(g.pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric ) AS diff
  FROM game g
  WHERE LEFT(COALESCE(g.season::text,''),4) IN ('2017','2018')
  UNION ALL
  SELECT
    g.season,
    g.team_abbreviation_away,
    g.team_name_away,
    ( NULLIF(regexp_replace(COALESCE(g.pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric
    - NULLIF(regexp_replace(COALESCE(g.pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric )
  FROM game g
  WHERE LEFT(COALESCE(g.season::text,''),4) IN ('2017','2018')
),
avgd AS (
  SELECT season, team_abbr, team_name, AVG(diff) AS avg_diff
  FROM base
  GROUP BY season, team_abbr, team_name
),
ranked AS (
  SELECT season, team_abbr, team_name, avg_diff,
         ROW_NUMBER() OVER (PARTITION BY season ORDER BY avg_diff DESC) AS rn
  FROM avgd
)
SELECT season, team_abbr, team_name, avg_diff
FROM ranked
WHERE LEFT(season::text,4)='2017' AND rn=1
UNION ALL
SELECT season, team_abbr, team_name, avg_diff
FROM ranked
WHERE LEFT(season::text,4)='2018' AND rn=1
ORDER BY season;
```

Answer:
```
2017	"HOU"	"Houston Rockets"	8.4756097560975610
2018	"MIL"	"Milwaukee Bucks"	8.8658536585365854
```

7) ¿Quién es el jugador más valioso del draft1 del 2018 hoy en día?
```
WITH d AS (
  SELECT
    LOWER(regexp_replace(COALESCE(nameplayer::text,''), '[^a-z0-9]', '', 'g')) AS key_name,
    nameplayer
  FROM draft
  WHERE NULLIF(regexp_replace(COALESCE(yeardraft::text,''),'[^0-9.\-]','','g'),'')::numeric = 2018
    AND NULLIF(regexp_replace(COALESCE(numberround::text,''),'[^0-9.\-]','','g'),'')::numeric = 1
),
sal AS (
  SELECT
    LOWER(regexp_replace(COALESCE(nameplayer::text,''), '[^a-z0-9]', '', 'g')) AS key_name,
    nameplayer,
    slugseason,
    NULLIF(regexp_replace(COALESCE(value::text,''),'[^0-9.\-]','','g'),'')::numeric AS salary,
    NULLIF(substring(slugseason from '^\d{4}'), '')::int AS season_start
  FROM player_salary
  WHERE value IS NOT NULL
),
last_sal AS (
  SELECT *
  FROM (
    SELECT
      key_name, nameplayer, slugseason, season_start, salary,
      ROW_NUMBER() OVER (PARTITION BY key_name ORDER BY season_start DESC NULLS LAST) AS rn
    FROM sal
  ) x
  WHERE rn = 1
)
SELECT ls.nameplayer, ls.slugseason, ls.salary
FROM d
JOIN last_sal ls USING (key_name)
ORDER BY ls.salary DESC NULLS LAST
LIMIT 1;
```

Respuesta:
```
"Deandre Ayton"	"2022-23"	16422835.0
```

8) Top 5 estados con más salarios en 2020/2021 y 2021/2022 (Se mapea primero en nuestro caso).
```
WITH team_state AS (
  SELECT * FROM (VALUES
    ('Atlanta Hawks','GA'), ('Boston Celtics','MA'), ('Brooklyn Nets','NY'), ('Charlotte Hornets','NC'),
    ('Chicago Bulls','IL'), ('Cleveland Cavaliers','OH'), ('Dallas Mavericks','TX'), ('Denver Nuggets','CO'),
    ('Detroit Pistons','MI'), ('Golden State Warriors','CA'), ('Houston Rockets','TX'), ('Indiana Pacers','IN'),
    ('LA Clippers','CA'), ('Los Angeles Lakers','CA'), ('Memphis Grizzlies','TN'), ('Miami Heat','FL'),
    ('Milwaukee Bucks','WI'), ('Minnesota Timberwolves','MN'), ('New Orleans Pelicans','LA'), ('New York Knicks','NY'),
    ('Oklahoma City Thunder','OK'), ('Orlando Magic','FL'), ('Philadelphia 76ers','PA'), ('Phoenix Suns','AZ'),
    ('Portland Trail Blazers','OR'), ('Sacramento Kings','CA'), ('San Antonio Spurs','TX'), ('Toronto Raptors','ON'),
    ('Utah Jazz','UT'), ('Washington Wizards','DC')
  ) AS t(team, state)
),
ps AS (
  SELECT
    ps.slugseason,
    ps.nameteam AS team,
    NULLIF(regexp_replace(COALESCE(ps.value::text,''),'[^0-9.\-]','','g'),'')::numeric AS salary
  FROM player_salary ps
  WHERE ps.slugseason IN ('2020-21','2021-22')
)
SELECT ts.state, SUM(ps.salary) AS total_salary
FROM ps
JOIN team_state ts ON ts.team = ps.team
GROUP BY ts.state
ORDER BY total_salary DESC NULLS LAST
LIMIT 5;
```

Respuesta:
```
"CA"	802295276.0
"TX"	643817164.0
"NY"	492334504.0
"FL"	466387189.0
"WI"	279414350.0
```
