# Fitness database – stored procedure archive

Source: `Fitness.dacpac` extracted 2026-09-02 from SQL Server 2025 (DacFx 170.5.76).
Procedures and functions were fixed on 2026-10-14 before archiving; see `CHANGELOG.md`.

| Folder / file | Contents |
|---|---|
| `procedures/` | 112 stored procedures — **fixed** versions, one `CREATE OR ALTER` script each, with a `-- Changes:` header |
| `functions/` | 5 scalar functions — fixed versions |
| `procedures-original/` | the same 112 procedures exactly as they were in the dacpac, before the fixes |
| `functions-original/` | the 5 functions before the fixes |
| `views/` | 10 views (live — the API reads them for reports; snapshot of the current definitions) |
| `CHANGELOG.md` | every change, per object, plus the conventions applied to all of them |
| `scripts/00_usage_audit.sql` | proves the procedures are unused; lists real dependencies and permissions |
| `scripts/00c_test_procedure_fixes.sql` | deploys the fixed versions into a scratch schema and compares them with the current ones on your data; changes nothing |
| `scripts/00b_apply_procedure_fixes.sql` | applies all fixes to `dbo` (CREATE OR ALTER, re-runnable) |
| `scripts/01_move_to_archive_schema.sql` | moves procs + 3 orphan functions to an `archive` schema (reversible) |
| `scripts/01b_archive_gpx_tables.sql` | moves the six legacy `*GPX` tables (with data) to `archive` and drops their FKs; GpxJson is the live design |
| `scripts/02_rollback_archive.sql` | undoes step 01 (procedures and functions only) |
| `scripts/02b_rollback_gpx_archive.sql` | undoes step 01b |
| `scripts/03_drop_archived_objects.sql` | final removal of the archived procedures/functions after the quarantine period |
| `scripts/04_permissions.sql` | `FitnessApp` role (read/write on `dbo`) for the .NET service; removes legacy roles/users and the retired YELLOWCADDIS domain accounts; preview by default (`@Apply = 0`) |
| `scripts/03b_drop_gpx_tables.sql` | final removal of the archived GPX tables (refuses if any GPX exists only there) |

## Order to run

1. `00_usage_audit.sql` — confirm nothing calls the procedures.
2. `00c_test_procedure_fixes.sql` — `sqlcmd -S <server> -d Fitness -E -I -i 00c_test_procedure_fixes.sql -o fixtest_results.txt`.
   Look at the summary at the end: there should be no `FIXED-ERROR`, `UNEXPECTED-DIFF` or `FAIL` lines.
3. `00b_apply_procedure_fixes.sql` — `sqlcmd -S <server> -d Fitness -E -I -b -i 00b_apply_procedure_fixes.sql`.
   Not atomic: if it stops part-way, fix the cause and re-run it (every object is CREATE OR ALTER).
4. `01_move_to_archive_schema.sql`, then `01b_archive_gpx_tables.sql` (it stops if anything in `dbo` still uses the GPX tables).
5. `04_permissions.sql` — set `@ServiceUser`, run once to preview, then again with `@Apply = 1`.
6. Quarantine (~60 days), then `03_drop_archived_objects.sql` and, after a backup (and a `bcp` export if you want the raw GPX XML),
   `03b_drop_gpx_tables.sql`.

## Notes after the fixes

- `ExceptionalMiles` is no longer called by any procedure; `OdometerReading` is called only by `GetPartAge`.
  Step 01 still moves only the three functions that had no callers before (`MaximumRideDate`, `MinimumRideDate`,
  `ToDecimalHours`); add the other two to step 01 if the usage audit shows the API doesn't call them.
- The fixes were validated without a SQL Server instance (parsers plus a column/parameter checker against the dacpac
  model, and an independent review). Step 2 is the run-time test on the real engine and data.

Commit this whole folder to the repository that holds the API (e.g. `db/archive/`) so the original and fixed T-SQL
stay next to the C# that replaced it.
