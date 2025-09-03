# CSV Data Cleaning for PostgreSQL Import

This README documents the steps needed to clean NBA Game CSV data for successful import into PostgreSQL.

## Problem Overview

The original CSV file had several issues preventing direct import:
- Commas within quoted date fields (e.g., `"FRIDAY NOVEMBER 1, 1946"`)
- Invalid time formats (e.g., `"1:60"`, `"208:23"`) 
- Column size limitations for broadcast information
- Duplicate records with the same primary key

## Data Cleaning Steps

### Step 1: Remove Commas from Quoted Fields

**Problem**: Date fields contain commas that break CSV parsing
```
"FRIDAY NOVEMBER 1, 1946" → causes column misalignment
```

**Solution**: Use Perl to remove commas within quoted fields
```bash
perl -pe 's/"([^"]*)"/($x=$1) =~ s#,# #g; "\"$x\""/ge' Game.csv > Game_clean.csv
```

This command:
- Matches any content within quotes `"([^"]*)"`
- Removes all commas within those quotes
- Replaces commas with spaces
- Preserves the quote structure

### Step 2: Handle Time Format Issues

**Problem**: Game duration stored as `minutes:seconds` format exceeds TIME data type limits
```
"208:23" → Invalid for PostgreSQL TIME type (hours must be 0-23)
```

**Solution**: Change database column type to INTERVAL
```sql
ALTER TABLE Game ALTER COLUMN GAME_TIME TYPE INTERVAL USING NULL;
```

**Then convert CSV format to PostgreSQL interval format:**
```bash
perl -pe 's/(\d+):(\d+)/"$1 minutes $2 seconds"/g' Game_clean.csv > Game_duration_fixed.csv
```

### Step 3: Fix Column Size Limitations

**Problem**: Broadcast information exceeds VARCHAR(10) limit
```
"Q4  - ESPN3D" → 13 characters, exceeds 10-character limit
```

**Solution**: Increase column size
```sql
ALTER TABLE Game ALTER COLUMN LIVE_PERIOD_TIME_BCAST TYPE VARCHAR(50);
```

### Step 4: Remove Duplicate Records

**Problem**: Duplicate GAME_ID values violate primary key constraint
```
ERROR: duplicate key value violates unique constraint "game_pkey"
```

**Solution**: Remove duplicates, keeping the last occurrence (most complete data)
```bash
# Method 1: Keep first occurrence
awk -F, 'NR==1 || !seen[$1]++' Game_duration_fixed.csv > Game_no_duplicates.csv

# Method 2: Keep last occurrence (recommended for game data)
tac Game_duration_fixed.csv | awk -F, '!seen[$1]++' | tac > Game_no_duplicates.csv
```

**Why keep the last occurrence?**
- Game data gets updated as games progress (live → final)
- Final scores and complete statistics are added later
- Last occurrence typically has the most complete information

## Complete Workflow

```bash
# Step 1: Clean quoted fields
perl -pe 's/"([^"]*)"/($x=$1) =~ s#,# #g; "\"$x\""/ge' Game.csv > Game_clean.csv

# Step 2: Fix time format  
perl -pe 's/(\d+):(\d+)/"$1 minutes $2 seconds"/g' Game_clean.csv > Game_duration_fixed.csv

# Step 3: Remove duplicates (keep last occurrence)
tac Game_duration_fixed.csv | awk -F, '!seen[$1]++' | tac > Game_final.csv
```

```sql
-- Step 4: Adjust database schema
ALTER TABLE Game ALTER COLUMN GAME_TIME TYPE INTERVAL USING NULL;
ALTER TABLE Game ALTER COLUMN LIVE_PERIOD_TIME_BCAST TYPE VARCHAR(50);

-- Step 5: Import cleaned data
COPY Game FROM '/tmp/Game_final.csv' DELIMITER ',' CSV HEADER NULL AS '';
```

## Verification Steps

After import, verify the data:

```sql
-- Check record count
SELECT COUNT(*) FROM Game;

-- Verify no duplicates
SELECT GAME_ID, COUNT(*) FROM Game GROUP BY GAME_ID HAVING COUNT(*) > 1;

-- Check time format
SELECT GAME_TIME FROM Game WHERE GAME_TIME IS NOT NULL LIMIT 5;

-- Test your original query
SELECT t.ID 
FROM Game g 
JOIN Team_Attributes t ON g.TEAM_ID_HOME = t.ID 
GROUP BY t.ID;
```

## Tools Used

- **Perl**: Advanced pattern matching for complex CSV cleaning
- **awk**: Field-based processing for duplicate removal  
- **tac**: Reverse file order to keep last occurrences
- **PostgreSQL**: Database with robust data type handling

## Key Learnings

1. **Real-world CSV files rarely import cleanly** - always expect data quality issues
2. **Perl is powerful for complex text processing** - better than sed for nested patterns
3. **Data types matter** - choose appropriate types (INTERVAL vs TIME) for your use case
4. **Duplicate handling requires business logic** - decide based on data completeness and recency
5. **Test incrementally** - fix one issue at a time to isolate problems

## File Structure
```
/tmp/
├── Game.csv              # Original file
├── Game_clean.csv        # After comma removal
├── Game_duration_fixed.csv # After time format fix
└── Game_final.csv        # Final cleaned file ready for import
```
