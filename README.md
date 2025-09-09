# NBA Data Analysis

## Diagrama Entidad-relación
<img width="3840" height="1762" alt="Untitled diagram _ Mermaid Chart-2025-09-09-053153" src="https://github.com/user-attachments/assets/b5ffdf2d-d1af-4788-aa09-f07762a93cf6" />


## Data cleaning

Encontramos un problema en el archivo `Player_Attributes.csv`, la 4ta columna `DISPLAY_FIRST_LAST` tenía una coma en la columna, estaba rompiendo la estructura del csv. Para arreglarlo, usamos el comando `sed`:

```
sed -E 's/"([^,]+), ([^"]+)"/"\1 \2"/g' Player_Attributes.csv > Player_Attributes_clean.csv
```
Básicamente

`[^,]+`: One or more characters that aren't commas
`[^"]+`: One or more characters that aren't quotes

Esto transforma:

"John, Doe" → "John Doe"

## Database Setup

La base de datos está en docker, así que usamos el comando `docker cp` para copiar los `csv` dentro del docker. Aquí usamos `psql` para correr el archivo `setup.sql`.
Este archivo contiene queries para crear las tablas. También contiene la función `COPY` para copiar la data del csv a la base de datos.

## Preguntas

1. ¿Quién es el jugador activo más alto? ¿Y el más bajo?

- Query:

```
SELECT p.full_name, pa.height
FROM player p
JOIN player_attributes pa ON p.id = pa.id
WHERE p.is_active = TRUE
ORDER BY pa.height DESC
LIMIT 1;
```

Respuesta

```
 full_name  | height
------------+--------
 Tacko Fall | 89.0
(1 row)

```

1.2.  ¿Y el más bajo?


```
SELECT p.full_name, pa.height
FROM player p
JOIN player_attributes pa ON p.id = pa.id
WHERE p.is_active = TRUE
ORDER BY pa.height ASC
LIMIT 1;
```

Respuesta:

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
Respuesta: Demasiado largo para poner aquí

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

9) Win% local vs visita
Querie:
```
WITH g0 AS (
  SELECT
    *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (
  SELECT season_start, COUNT(*) AS games
  FROM g0
  WHERE season_start IS NOT NULL
  GROUP BY 1
),
target AS (
  -- usa 2021 si existe; si no, usa la más reciente disponible
  SELECT 2021 AS season_start
  WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)
  UNION ALL
  SELECT MAX(season_start) FROM seasons
  WHERE NOT EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)
  LIMIT 1
),
g AS (SELECT g0.* FROM g0 JOIN target t USING (season_start)),
home AS (
  SELECT team_name_home AS team,
         (UPPER(COALESCE(wl_home::text,''))='W')::int AS win
  FROM g
),
away AS (
  SELECT team_name_away AS team,
         (UPPER(COALESCE(wl_away::text,''))='W')::int AS win
  FROM g
),
home_win AS (SELECT team, SUM(win)::numeric/COUNT(*) AS home_win_pct FROM home GROUP BY team),
away_win AS (SELECT team, SUM(win)::numeric/COUNT(*) AS away_win_pct FROM away GROUP BY team)
SELECT h.team,
       ROUND(h.home_win_pct,4) AS home_win_pct,
       ROUND(a.away_win_pct,4) AS away_win_pct,
       ROUND(h.home_win_pct - a.away_win_pct,4) AS home_minus_away_gap
FROM home_win h
JOIN away_win a USING (team)
ORDER BY away_win_pct DESC;
```

Respuesta (HAY 30 SE COLOCARON SOLO 5):
```
"Phoenix Suns"	0.6389	0.6667	-0.0278
"LA Clippers"	0.6389	0.5946	0.0443
"Portland Trail Blazers"	0.4595	0.5833	-0.1239
"Los Angeles Lakers"	0.4865	0.5833	-0.0968
"Indiana Pacers"	0.3333	0.5833	-0.2500
```

10) “Clutch”: victorias con margen ≤ 5 puntos
Querie:
```
WITH g0 AS (
  SELECT
    *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (
  SELECT season_start, COUNT(*) FROM g0 WHERE season_start IS NOT NULL GROUP BY 1
),
desired AS (
  SELECT COALESCE(
           (SELECT 2021 WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)),
           (SELECT MAX(season_start) FROM seasons)
         ) AS season_start
),
g AS (
  SELECT g0.* FROM g0 JOIN desired d ON g0.season_start = d.season_start
),
m AS (
  SELECT
    team_name_home AS team,
    (UPPER(COALESCE(wl_home::text,''))='W')::int AS win,
    ABS(
      NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric -
      NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric
    ) AS margin
  FROM g
  UNION ALL
  SELECT
    team_name_away,
    (UPPER(COALESCE(wl_away::text,''))='W')::int,
    ABS(
      NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric -
      NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric
    )
  FROM g
)
SELECT team,
       SUM(CASE WHEN margin <= 5 THEN win ELSE 0 END) AS close_wins,
       SUM(CASE WHEN margin <= 5 THEN 1   ELSE 0 END) AS close_games,
       ROUND(
         SUM(CASE WHEN margin <= 5 THEN win ELSE 0 END)::numeric /
         NULLIF(SUM(CASE WHEN margin <= 5 THEN 1 ELSE 0 END),0), 4
       ) AS close_win_pct
FROM m
GROUP BY team
ORDER BY close_win_pct DESC NULLS LAST, close_wins DESC;
```

11) “Aplasta rivales”: % de victorias por ≥ 15 puntos
Querie:
```
WITH g0 AS (
  SELECT
    *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (
  SELECT season_start, COUNT(*) FROM g0 WHERE season_start IS NOT NULL GROUP BY 1
),
desired AS (
  SELECT COALESCE(
           (SELECT 2021 WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)),
           (SELECT MAX(season_start) FROM seasons)
         ) AS season_start
),
g AS (
  SELECT g0.* FROM g0 JOIN desired d ON g0.season_start = d.season_start
),
m AS (
  SELECT
    team_name_home AS team,
    (UPPER(COALESCE(wl_home::text,''))='W')::int AS win,
    ( NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric -
      NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric ) AS diff
  FROM g
  UNION ALL
  SELECT
    team_name_away,
    (UPPER(COALESCE(wl_away::text,''))='W')::int,
    ( NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric -
      NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric )
  FROM g
)
SELECT team,
       SUM(CASE WHEN diff >= 15 THEN 1 ELSE 0 END) AS blowout_wins,
       COUNT(*) AS total_games,
       ROUND(SUM(CASE WHEN diff >= 15 THEN 1 ELSE 0 END)::numeric/COUNT(*),4) AS blowout_win_share
FROM m
GROUP BY team
ORDER BY blowout_win_share DESC, blowout_wins DESC;
```

Respuesta (HAY 30 SE COLOCARON SOLO 5):
```
"Utah Jazz"	29	72	0.4028
"LA Clippers"	22	73	0.3014
"Philadelphia 76ers"	20	72	0.2778
"Denver Nuggets"	18	72	0.2500
"Phoenix Suns"	18	72	0.2500
```

12) Balance ofensivo/defensivo y ranking combinado
Querie:
```
WITH g0 AS (
  SELECT *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (
  SELECT season_start, COUNT(*) FROM g0 WHERE season_start IS NOT NULL GROUP BY 1
),
desired AS (
  SELECT COALESCE(
           (SELECT 2021 WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)),
           (SELECT MAX(season_start) FROM seasons)
         ) AS season_start
),
g AS (SELECT g0.* FROM g0 JOIN desired d ON g0.season_start = d.season_start),
u AS (
  SELECT team_name_home AS team,
         NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric AS pts_for,
         NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric AS pts_against
  FROM g
  UNION ALL
  SELECT team_name_away,
         NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric,
         NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric
  FROM g
),
base AS (
  SELECT team, AVG(pts_for) AS off, AVG(pts_against) AS def
  FROM u GROUP BY team
),
ranks AS (
  SELECT team,
         RANK() OVER (ORDER BY off DESC) AS off_rank,
         RANK() OVER (ORDER BY def ASC)  AS def_rank
  FROM base
)
SELECT b.team,
       ROUND(b.off,2) AS avg_pts_for,
       ROUND(b.def,2) AS avg_pts_against,
       r.off_rank,
       r.def_rank,
       (r.off_rank + r.def_rank) AS composite_rank
FROM base b
JOIN ranks r USING (team)
ORDER BY composite_rank ASC, off_rank ASC;
```

Respuesta (HAY 30 SE COLOCARON SOLO 5):
```
"Philadelphia 76ers"	113.64	108.06	6	8	14
"Phoenix Suns"	113.00	107.17	8	6	14
"Utah Jazz"	112.56	103.64	12	3	15
"Denver Nuggets"	112.47	107.15	13	5	18
"LA Clippers"	110.88	105.25	16	4	20
```

13) Brecha mínima entre local y visita
Querie:
```
WITH g0 AS (
  SELECT *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (SELECT season_start, COUNT(*) FROM g0 WHERE season_start IS NOT NULL GROUP BY 1),
desired AS (
  SELECT COALESCE(
           (SELECT 2021 WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)),
           (SELECT MAX(season_start) FROM seasons)
         ) AS season_start
),
g AS (SELECT g0.* FROM g0 JOIN desired d ON g0.season_start = d.season_start),
home AS (SELECT team_name_home AS team, (UPPER(COALESCE(wl_home::text,''))='W')::int AS win FROM g),
away AS (SELECT team_name_away AS team, (UPPER(COALESCE(wl_away::text,''))='W')::int AS win FROM g),
hw AS (SELECT team, SUM(win)::numeric/COUNT(*) AS home_win FROM home GROUP BY team),
aw AS (SELECT team, SUM(win)::numeric/COUNT(*) AS away_win FROM away GROUP BY team)
SELECT hw.team,
       ROUND(hw.home_win,4) AS home_win_pct,
       ROUND(aw.away_win,4) AS away_win_pct,
       ROUND(ABS(hw.home_win - aw.away_win),4) AS abs_gap
FROM hw JOIN aw USING (team)
ORDER BY abs_gap ASC, away_win_pct DESC;
```

Respuesta:
```
"Dallas Mavericks"	0.5556	0.5556	0.0000
"Phoenix Suns"	0.6389	0.6667	0.0278
"Chicago Bulls"	0.4167	0.4444	0.0278
"Orlando Magic"	0.3056	0.2778	0.0278
"Houston Rockets"	0.2500	0.2222	0.0278
```

14) “Forma” al final: win% en los últimos 30 días de la temporada
Querie:
```
WITH g0 AS (
  SELECT *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (SELECT season_start, COUNT(*) FROM g0 WHERE season_start IS NOT NULL GROUP BY 1),
desired AS (
  SELECT COALESCE(
           (SELECT 2021 WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)),
           (SELECT MAX(season_start) FROM seasons)
         ) AS season_start
),
g AS (SELECT g0.* FROM g0 JOIN desired d ON g0.season_start = d.season_start),
gd AS (
  SELECT g.*,
         COALESCE(
           NULLIF(substring(game_date::text     FROM '^\s*(\d{4}-\d{2}-\d{2})'), ''),
           NULLIF(substring(game_date_est::text FROM '^\s*(\d{4}-\d{2}-\d{2})'), '')
         )::date AS dt
  FROM g
),
cut AS (SELECT MAX(dt) - INTERVAL '30 days' AS cutoff FROM gd WHERE dt IS NOT NULL),
last AS (
  SELECT gd.*
  FROM gd, cut
  WHERE gd.dt IS NOT NULL AND gd.dt >= cut.cutoff
),
u AS (
  SELECT team_name_home AS team, (UPPER(COALESCE(wl_home::text,''))='W')::int AS win FROM last
  UNION ALL
  SELECT team_name_away,        (UPPER(COALESCE(wl_away::text,''))='W')::int FROM last
)
SELECT team,
       SUM(win) AS wins,
       COUNT(*) AS games,
       ROUND(SUM(win)::numeric/NULLIF(COUNT(*),0),4) AS win_pct_last_30d
FROM u
GROUP BY team
ORDER BY win_pct_last_30d DESC NULLS LAST, wins DESC;
```

Respuesta:
```
"New York Knicks"	12	16	0.7500
"Washington Wizards"	13	18	0.7222
"Miami Heat"	12	17	0.7059
"Atlanta Hawks"	11	16	0.6875
"Philadelphia 76ers"	11	17	0.6471
```

15) Score compuesto (win%, diferencial, eficiencia salarial, y (-) inactivos/juego)
Querie:
```
WITH g0 AS (
  SELECT *,
    COALESCE(
      CASE WHEN season_id::text ~ '^\s*\d{5,}$' THEN RIGHT(season_id::text, 4)::int END,
      NULLIF(substring(season::text FROM '(\d{4})'), '')::int
    ) AS season_start
  FROM game
),
seasons AS (SELECT season_start, COUNT(*) FROM g0 WHERE season_start IS NOT NULL GROUP BY 1),
desired AS (
  SELECT COALESCE(
           (SELECT 2021 WHERE EXISTS (SELECT 1 FROM seasons WHERE season_start = 2021)),
           (SELECT MAX(season_start) FROM seasons)
         ) AS season_start
),
g AS (SELECT g0.* FROM g0 JOIN desired d ON g0.season_start = d.season_start),
-- slug de salarios: ej. 2021 -> '2021-22'
slug AS (
  SELECT season_start,
         (season_start::text || '-' || RIGHT((season_start+1)::text, 2)) AS slugseason
  FROM desired
),
home AS (
  SELECT team_name_home AS team,
         (UPPER(COALESCE(wl_home::text,''))='W')::int AS win,
         NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric AS pf,
         NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric AS pa
  FROM g
),
away AS (
  SELECT team_name_away AS team,
         (UPPER(COALESCE(wl_away::text,''))='W')::int AS win,
         NULLIF(regexp_replace(COALESCE(pts_away::text,''),'[^0-9.\-]','','g'),'')::numeric AS pf,
         NULLIF(regexp_replace(COALESCE(pts_home::text,''),'[^0-9.\-]','','g'),'')::numeric AS pa
  FROM g
),
u AS (SELECT * FROM home UNION ALL SELECT * FROM away),
wins AS (
  SELECT team,
         SUM(win) AS wins,
         COUNT(*) AS games,
         SUM(win)::numeric/COUNT(*) AS win_pct,
         AVG(pf - pa) AS avg_point_diff
  FROM u GROUP BY team
),
pay AS (
  SELECT ps.nameteam AS team,
         SUM(NULLIF(regexp_replace(COALESCE(ps.value::text,''),'[^0-9.\-]','','g'),'')::numeric) AS payroll
  FROM player_salary ps
  JOIN slug s ON ps.slugseason = s.slugseason
  GROUP BY ps.nameteam
),
eff AS (
  SELECT w.team,
         (w.wins / NULLIF(p.payroll,0)) * 1000000 AS wins_per_million
  FROM wins w JOIN pay p ON p.team = w.team
),
inact AS (
  SELECT g.season_start, gip.team_name
  FROM game_inactive_players gip
  JOIN g ON g.game_id = gip.game_id
),
inact_counts AS (
  SELECT team_name AS team, COUNT(*) AS total_inactives
  FROM inact GROUP BY team_name
),
games_ct AS (
  SELECT team, COUNT(*) AS games
  FROM (SELECT team_name_home AS team FROM g UNION ALL SELECT team_name_away FROM g) x
  GROUP BY team
),
inact_rate AS (
  SELECT gc.team, COALESCE(ic.total_inactives,0)::numeric / NULLIF(gc.games,0) AS inactives_per_game
  FROM games_ct gc LEFT JOIN inact_counts ic ON ic.team = gc.team
),
all_metrics AS (
  SELECT w.team, w.win_pct, w.avg_point_diff, e.wins_per_million, i.inactives_per_game
  FROM wins w JOIN eff e ON e.team = w.team JOIN inact_rate i ON i.team = w.team
),
z AS (
  SELECT
    team,
    (win_pct - AVG(win_pct) OVER()) / NULLIF(STDDEV_SAMP(win_pct) OVER(),0)                             AS z_win,
    (avg_point_diff - AVG(avg_point_diff) OVER()) / NULLIF(STDDEV_SAMP(avg_point_diff) OVER(),0)         AS z_diff,
    (wins_per_million - AVG(wins_per_million) OVER()) / NULLIF(STDDEV_SAMP(wins_per_million) OVER(),0)   AS z_eff,
    (AVG(inactives_per_game) OVER() - inactives_per_game) / NULLIF(STDDEV_SAMP(inactives_per_game) OVER(),0) AS z_inact
  FROM all_metrics
)
SELECT team,
       ROUND(z_win,2)  AS z_win,
       ROUND(z_diff,2) AS z_diff,
       ROUND(z_eff,2)  AS z_eff,
       ROUND(z_inact,2) AS z_inact,
       ROUND((z_win + z_diff + z_eff + z_inact),2) AS composite_score
FROM z
ORDER BY composite_score DESC NULLS LAST;
```

Respuesta:
```
"Charlotte Hornets"	-0.14	-0.35	0.48
"Washington Wizards"	-0.03	-0.33	-0.14
"Cleveland Cavaliers"	-1.31	-1.69	-1.34
"Sacramento Kings"	-0.89	-0.62	-0.30
"New Orleans Pelicans"	-0.40	-0.05	-0.53
```
