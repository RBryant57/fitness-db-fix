# FitnessArchive

The retired parts of the Fitness database, kept in a database of their own so that Fitness has no `[archive]` schema.

| What | Where it came from |
|---|---|
| `dbo.TrainingRideGPX`, `TrainingRunGPX`, `TrainingWalkGPX`, `RecreationalRideGPX`, `RecreationalRunGPX`, `RecreationalWalkGPX` | The legacy GPX tables (original GPX XML; the API uses `Fitness.dbo.GpxJson`). Archived by `01b`. |
| `dbo.HRZones`, `dbo.HRZoneTime`, `dbo.BikeHistory` | Unused tables, archived by `fixes/S9-S10`. |
| `dbo.ArchiveLog` | The archive log, plus an entry for each copy (05) and for the drop from Fitness (06). |
| 111 procedures, 3 functions | The fixed versions, archived by `01`. **Reference only:** they read Fitness tables that are not here, so they do not run in this database. The API holds this logic now. |

Everything is in `dbo`. Nothing connects to this database: the API has no user here, and only administrators (sysadmin) read it.
Include it in the backup jobs.

## How it was built

1. `db/scripts/archive/scripts/05_copy_archive_to_database.sql` (`-Phase ArchiveDb -Apply`) created the database from
   `Fitness.[archive]` and compared every row and definition.
2. This project was extracted from the staging database:

   ```powershell
   cd E:\YellowCaddisDevelopment\YCDProjects\YCDData\Fitness\FitnessFix\db\FitnessArchive
   sqlpackage /Action:Extract /SourceServerName:.\DEVELOPMENT /SourceDatabaseName:FitnessArchive /SourceTrustServerCertificate:True `
       /TargetFile:src /p:ExtractTarget=SchemaObjectType /p:ExtractApplicationScopedObjectsOnly=True
   dotnet build
   ```

3. `Fitness.sqlproj` (repository root) excludes this folder with `<Build Remove="db\FitnessArchive\**" />`.

## Checking a server against the project

```powershell
sqlpackage /Action:DeployReport /SourceFile:bin\Debug\FitnessArchive.dacpac /TargetServerName:.\DEVELOPMENT `
    /TargetDatabaseName:FitnessArchive /TargetTrustServerCertificate:True /OutputPath:deployreport-archive.xml `
    /p:IgnoreComments=True /p:ExcludeObjectTypes="Logins;Users;RoleMembership"
```

An empty report means the database matches. On production, FitnessArchive is created the same way, by 05 from
production's own `[archive]` schema; the project is then only used for this check, not to publish.
