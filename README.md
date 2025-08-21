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



