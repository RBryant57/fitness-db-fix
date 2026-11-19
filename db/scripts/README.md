# db/scripts

Scripts and reference files for the Fitness database clean-up. Nothing here is part of the SQL project build
(`Fitness.sqlproj` has `<Build Remove="db\scripts\**" />`); these are run by hand with sqlcmd, in the order below.

| Folder | Contents |
|---|---|
| `archive/scripts/` | 00 usage audit, 00c test + 00b apply procedure fixes, 01 archive procedures, 01b archive legacy GPX tables, 01c restore GetLastEntries, 02/02b rollback, 03/03b final drops, 04 permissions |
| `procedures/` | Live stored procedures that stay in the database: `GetLastEntries.sql` (the API uses it; it is not archived) |
| `archive/procedures/`, `archive/functions/` | Fixed versions of the 111 archived procedures and 5 functions (reference after archiving) |
| (originals) | The pre-fix procedures and functions are in the baseline commit, under `db/Fitness/src/dbo/StoredProcedures` and `Functions` |
| `archive/CHANGELOG.md`, `archive/README.md` | Every change per object; archive run order |
| `tables/` | Definitions of the nine activity tables with computed durations, and a `rebuild_<Table>.sql` for each |
| `views/` | The eight revised report views (Duration hh:mm:ss, exact pace, no divide-by-zero) |
| `fixes/` | One script per remaining item (below). Each previews by default; `@Apply = 1` (or `-Phase Fix -Script <name> -Apply`) makes the change |

Run order on staging first (`-S .\DEVELOPMENT`), then production (`-S .`):

1. `archive/scripts/00_usage_audit.sql`
2. `archive/scripts/00c_test_procedure_fixes.sql` (check the summary), then `00b_apply_procedure_fixes.sql`
3. `archive/scripts/01_move_to_archive_schema.sql` (moves every procedure except `GetLastEntries`), then `01b_archive_gpx_tables.sql`.
   On staging, where an earlier 01 already archived `GetLastEntries`, run `01c_restore_GetLastEntries.sql` once to move it back.
4. `tables/00_fix_duration_data.sql` (preview, then `@Apply = 1`): end times from the stored durations, no negative rest,
   six walk distances from GPS. Then the revised views (`views/`), then `tables/rebuild_<Table>.sql` for each table (preview, then `@Apply = 1`)
5. `fixes/S2_missedmiles_date_default.sql`; `fixes/O1-O3_database_settings.sql` with `@Step = 1`, then a few days later `@Step = 2`
6. `archive/scripts/04_permissions.sql` once the API has its own identity
7. The remaining items, in this order (each: preview, then apply):
   1. `fixes/S15_drop_view_designer_properties.sql`, `fixes/S14_rename_objects.sql` (run S14 after the Duration rebuild)
   2. `fixes/D1_gps_link_cleanup.sql`: unlinks the ten rides that carry another ride's GPS track, deletes the duplicate tracks
   3. `fixes/S9-S10_archive_unused_tables.sql`: HRZones, HRZoneTime, BikeHistory to `[archive]` (`@Rollback = 1` undoes it)
   4. `fixes/S11_drop_magic_defaults.sql`: after the API always sends ShoeId, Route.TypeId and MaxSpeed
   5. `fixes/S12-S13_column_types.sql`: dates to `date`, three names to `nvarchar(50)` (not the activity tables)
   6. `-Phase Duration -Apply`: the activity tables' rebuild now also makes `[Date]` date and the times `datetime2(0)` (S13),
      creates the S7 checks and leaves out the S11 defaults. A table already rebuilt is rebuilt again until its times are datetime2.
   7. `fixes/S7_check_constraints.sql` (adds any check the rebuild didn't), `fixes/S8_indexes.sql`, `fixes/V3_maintenancelog_bikeid.sql`
   8. `fixes/S16_distance_report.sql`: read-only, for the S16 decision
8. After the quarantine period: `03_drop_archived_objects.sql`, `03b_drop_gpx_tables.sql`

After each step: re-import the project from the database (or make the same edit), build, commit.

## Running the scripts

`Run-FitnessScripts.ps1` runs them in order, one phase at a time, and saves every script's output to `logs\` (ignored by Git):

```powershell
cd db\scripts
.\Run-FitnessScripts.ps1 -Phase Audit
.\Run-FitnessScripts.ps1 -Phase Test                       # stops on FIXED-ERROR / UNEXPECTED-DIFF / FAIL
.\Run-FitnessScripts.ps1 -Phase Archive                    # 00b, 01, 01c, 01b
.\Run-FitnessScripts.ps1 -Phase DataFix [-Apply]          # data corrections before the rebuild
.\Run-FitnessScripts.ps1 -Phase Duration                   # views + rebuild preview
.\Run-FitnessScripts.ps1 -Phase Duration -Apply            # views + rebuild
.\Run-FitnessScripts.ps1 -Phase Permissions -ServiceUser 'IIS APPPOOL\<Pool>' [-Apply]
.\Run-FitnessScripts.ps1 -Phase Fix -Script S8_indexes [-Apply]   # any script in fixes\
.\Run-FitnessScripts.ps1 -Phase Drop                       # after the quarantine period
```

The default target is staging (`.\DEVELOPMENT`). For production add `-Server . -Production`; you are asked to type the server name to confirm.

Running one script by hand: `sqlcmd -S .\DEVELOPMENT -d Fitness -E -I -b -i archive\scripts\01_move_to_archive_schema.sql`

## Live procedure: GetLastEntries

`dbo.GetLastEntries` is the one stored procedure that stays in the database; the API uses it. `00b` deploys its fixed version
(explicit columns, and Stairs added as "Last Stair Session", a new row in its result), `01` leaves it in `dbo`, `03` never drops it,
and `04_permissions.sql` grants `EXECUTE` on it to `FitnessApp`. Its definition is `procedures/GetLastEntries.sql` and, in the SQL project,
`db/Fitness/src/dbo/StoredProcedures/GetLastEntries.sql`.
