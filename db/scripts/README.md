# db/scripts

Scripts and reference files for the Fitness database clean-up. Nothing here is part of the SQL project build
(`Fitness.sqlproj` has `<Build Remove="db\scripts\**" />`); these are run by hand with sqlcmd, in the order below.

| Folder | Contents |
|---|---|
| `archive/scripts/` | 00 usage audit, 00c test + 00b apply procedure fixes, 01 archive procedures, 01b archive legacy GPX tables, 02/02b rollback, 03/03b final drops, 04 permissions |
| `archive/procedures/`, `archive/functions/` | Fixed versions of the 112 procedures and 5 functions (reference after archiving) |
| (originals) | The pre-fix procedures and functions are in the baseline commit, under `db/Fitness/src/dbo/StoredProcedures` and `Functions` |
| `archive/CHANGELOG.md`, `archive/README.md` | Every change per object; archive run order |
| `tables/` | Definitions of the nine activity tables with computed durations, and a `rebuild_<Table>.sql` for each |
| `views/` | Revised report views (Duration hh:mm:ss, exact pace, no divide-by-zero) |

Run order on staging first (`-S .\DEVELOPMENT`), then production (`-S .`):

1. `archive/scripts/00_usage_audit.sql`
2. `archive/scripts/00c_test_procedure_fixes.sql` (check the summary), then `00b_apply_procedure_fixes.sql`
3. `archive/scripts/01_move_to_archive_schema.sql`, then `01b_archive_gpx_tables.sql`
4. Revised views (`views/`), then `tables/rebuild_<Table>.sql` for each table (preview, then `@Apply = 1`)
5. `archive/scripts/04_permissions.sql` once the API has its own identity
6. After the quarantine period: `03_drop_archived_objects.sql`, `03b_drop_gpx_tables.sql`

After each step: re-import the project from the database (or make the same edit), build, commit.

Example: `sqlcmd -S .\DEVELOPMENT -d Fitness -E -I -b -i archive\scripts\01_move_to_archive_schema.sql`
