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

