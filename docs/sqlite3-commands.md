Here are the most useful SQLite3 dot commands and SQL statements for examining database structure and information:

## Essential Dot Commands

```bash
# Database and table structure
.schema                    # Show CREATE statements for all tables
.schema table_name         # Show CREATE statement for specific table
.tables                    # List all tables in database
.indices                   # List all indices
.indices table_name        # List indices for specific table

# Database information
.databases                 # List attached databases
.dbinfo                    # Show database file information
.dbconfig                  # Show database configuration

# Output formatting
.headers on                # Show column headers in output
.mode column               # Display results in columns
.mode table                # Display results in table format
.width 10 20 15           # Set column widths

# Import/Export and backup
.dump                      # Export entire database as SQL
.dump table_name          # Export specific table as SQL
.backup backup.db         # Create backup of database

# System information
.show                      # Show current settings
.help                      # Show all available commands
```

## Essential SQL Statements

```sql
-- Table structure and metadata
PRAGMA table_info(table_name);           -- Column details (name, type, nullable, etc.)
PRAGMA table_list;                       -- List all tables with schema info
PRAGMA foreign_key_list(table_name);     -- Foreign key constraints
PRAGMA index_list(table_name);           -- Indices on table
PRAGMA index_info(index_name);           -- Details about specific index

-- Database metadata
PRAGMA database_list;                    -- List attached databases
PRAGMA compile_options;                  -- SQLite compile options
PRAGMA integrity_check;                  -- Check database integrity
PRAGMA quick_check;                      -- Quick integrity check

-- Performance and statistics
PRAGMA table_xinfo(table_name);          -- Extended table info
PRAGMA stats;                            -- Database statistics
ANALYZE;                                 -- Update query planner statistics

-- System tables (SQLite metadata)
SELECT * FROM sqlite_master;             -- All database objects
SELECT * FROM sqlite_master WHERE type='table';  -- Just tables
SELECT * FROM sqlite_master WHERE type='index';  -- Just indices
```

## Common Usage Patterns

```bash
# Quick database overview
sqlite3 mydb.db ".tables"
sqlite3 mydb.db ".schema"

# Examine specific table
sqlite3 mydb.db "PRAGMA table_info(users);"
sqlite3 mydb.db ".schema users"

# Interactive session with better formatting
sqlite3 mydb.db
.headers on
.mode column
.width 15 20 10
SELECT * FROM users LIMIT 5;
```

## Most Frequently Used Commands

1. **`.tables`** - Quick table listing
2. **`.schema`** - See table structures
3. **`PRAGMA table_info()`** - Detailed column information
4. **`.headers on` + `.mode column`** - Better output formatting
5. **`SELECT * FROM sqlite_master`** - Complete database metadata
6. **`.dump`** - Backup/export functionality

These commands will give you comprehensive insight into your SQLite database structure, constraints, and metadata.