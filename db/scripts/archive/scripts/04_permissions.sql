-- 04_permissions.sql
-- Least-privilege access for the .NET service, and removal of legacy principals, including every account from the
-- retired YELLOWCADDIS domain (those accounts can never log in again).
--
-- End state
--   * Role FitnessApp: SELECT, INSERT, UPDATE, DELETE on SCHEMA::dbo (tables and the report views, including any added
--     later). It has no rights on the [archive] schema and no DDL rights.
--   * The service's database user is a member of FitnessApp and of nothing else.
--   * Your admin login is the only member of db_owner. The database itself is owned by sa (or the login you choose).
--   * Legacy roles FitnessLogger / FitnessViewer, the legacy users and the YELLOWCADDIS logins are removed.
--
-- How to run
--   1. Check the service's connection string to find which login it uses, and set the variables in Part 1.
--      Part 2 also lists current connections to Fitness, which shows the logins in use right now.
--   2. Run with @Apply = 0 (the default): nothing changes; every statement it would run is printed.
--   3. Review the printed statements, then set @Apply = 1 and run again. Each statement checks before acting, so the
--      script can be re-run. It stops at the first error.
--   Run after 01_move_to_archive_schema.sql and 01b_archive_gpx_tables.sql.
--   sqlcmd -S <server> -d Fitness -E -I -b -i 04_permissions.sql      (or use -U/-P with your admin SQL login)
--
-- Part 0 (optional, run by hand first): a login for the service, if it doesn't have a suitable one yet
-- ------------------------------------------------------------------------------------------------------------------
-- A. Service runs on another machine or in a container: SQL authentication. Keep the password in an environment
--    variable or secret store, not appsettings.json.
--      CREATE LOGIN fitness_app WITH PASSWORD = N'<long random password>', CHECK_POLICY = ON, DEFAULT_DATABASE = Fitness;
--      USE Fitness; CREATE USER fitness_app FOR LOGIN fitness_app;
--    Connection string: Server=<server>;Database=Fitness;User ID=fitness_app;Password=...;Encrypt=True;
--      TrustServerCertificate=True   <- only if the server uses a self-signed certificate on your LAN
-- B. Service runs under IIS on the SQL Server machine: Windows authentication with the app pool identity.
--      CREATE LOGIN [IIS APPPOOL\<PoolName>] FROM WINDOWS;
--      USE Fitness; CREATE USER [IIS APPPOOL\<PoolName>] FOR LOGIN [IIS APPPOOL\<PoolName>];
-- C. Service runs as a Windows service on the SQL Server machine: its virtual account.
--      CREATE LOGIN [NT SERVICE\<ServiceName>] FROM WINDOWS;
--      USE Fitness; CREATE USER [NT SERVICE\<ServiceName>] FOR LOGIN [NT SERVICE\<ServiceName>];
--    For B and C: Server=<server>;Database=Fitness;Integrated Security=True;Encrypt=True;TrustServerCertificate=True
-- Then put that user's name in @ServiceUser below.

SET NOCOUNT ON;

IF DB_NAME() <> N'Fitness'
BEGIN
    RAISERROR(N'04_permissions.sql must be run in the Fitness database. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;
GO

------------------------------------------------------------------------------------------------------------------
-- Part 1: settings
------------------------------------------------------------------------------------------------------------------
DECLARE @Apply       bit     = 0;                  -- 0 = preview only, 1 = make the changes
DECLARE @ServiceUser sysname = N'container_user';  -- database user the .NET service connects as
DECLARE @AdminUser   sysname = N'Rick';            -- database user that stays in db_owner
DECLARE @DbOwner     sysname = N'sa';              -- login that will own the database (must NOT be a user in Fitness)

-- Legacy database users to drop (from the dacpac). Any other user named YELLOWCADDIS\... is added automatically.
-- @ServiceUser and @AdminUser are never dropped, even if listed here. container_user is listed so that it is removed
-- if you move the service to a new login (Part 0); while it is @ServiceUser it is kept.
DECLARE @DropUsers TABLE (name sysname PRIMARY KEY);
INSERT @DropUsers VALUES (N'FitnessUser'), (N'ElevatedUser'), (N'StandardUser'), (N'RouteService'),
                         (N'container_user'), (N'NT AUTHORITY\SYSTEM'),
                         (N'YELLOWCADDIS\commutetrackerservic'), (N'yellowcaddis\sqlservice');

DECLARE @DropRoles TABLE (name sysname PRIMARY KEY);
INSERT @DropRoles VALUES (N'FitnessLogger'), (N'FitnessViewer');

------------------------------------------------------------------------------------------------------------------
-- Part 2: report (no changes)
------------------------------------------------------------------------------------------------------------------
PRINT N'== Current connections to Fitness (shows which logins are in use right now)';
SELECT s.login_name, s.host_name, s.program_name, COUNT(*) AS Sessions, MAX(s.last_request_end_time) AS LastRequest
FROM sys.dm_exec_sessions AS s
WHERE s.database_id = DB_ID() AND s.is_user_process = 1
GROUP BY s.login_name, s.host_name, s.program_name;

PRINT N'== Database users and roles';
SELECT dp.name, dp.type_desc, sp.name AS LoginName,
       CASE WHEN dp.name LIKE N'YELLOWCADDIS\%' THEN N'retired domain'
            WHEN sp.sid IS NULL AND dp.type IN ('S', 'U', 'G') AND dp.authentication_type <> 0 THEN N'orphaned'
            ELSE N'' END AS Note,
       STUFF((SELECT N', ' + r.name FROM sys.database_role_members rm
              JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
              WHERE rm.member_principal_id = dp.principal_id FOR XML PATH('')), 1, 2, N'') AS MemberOf
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.principal_id > 4 AND dp.is_fixed_role = 0
ORDER BY dp.type_desc, dp.name;

PRINT N'== Owners (database, schemas, roles, SQL Agent jobs)';
SELECT N'database' AS Kind, name AS Name, ISNULL(SUSER_SNAME(owner_sid), N'<unresolvable>') AS Owner
FROM sys.databases WHERE name = DB_NAME()
UNION ALL
SELECT N'schema', name, USER_NAME(principal_id) FROM sys.schemas WHERE principal_id > 4 AND principal_id < 16384
UNION ALL
SELECT N'role', name, USER_NAME(owning_principal_id) FROM sys.database_principals WHERE type = 'R' AND is_fixed_role = 0
UNION ALL
SELECT N'job', name, ISNULL(SUSER_SNAME(owner_sid), N'<unresolvable>') FROM msdb.dbo.sysjobs;

------------------------------------------------------------------------------------------------------------------
-- Part 3: build the list of statements
------------------------------------------------------------------------------------------------------------------
IF USER_ID(@ServiceUser) IS NULL
BEGIN
    RAISERROR(N'@ServiceUser %s is not a user in Fitness. Create it (Part 0) or fix the setting. Nothing was changed.', 16, 1, @ServiceUser);
    RETURN;
END;
IF SUSER_SID(@DbOwner) IS NULL
BEGIN
    RAISERROR(N'@DbOwner %s is not a login on this server. Nothing was changed.', 16, 1, @DbOwner);
    RETURN;
END;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE sid = SUSER_SID(@DbOwner) AND name <> N'dbo')
BEGIN
    RAISERROR(N'@DbOwner %s is a user in Fitness, so it cannot own the database. Use sa or another login. Nothing was changed.', 16, 1, @DbOwner);
    RETURN;
END;

DELETE @DropUsers WHERE name IN (@ServiceUser, @AdminUser);
INSERT @DropUsers (name)
SELECT name FROM sys.database_principals
WHERE type IN ('U', 'G') AND name LIKE N'YELLOWCADDIS\%' AND name NOT IN (SELECT name FROM @DropUsers);
DELETE @DropUsers WHERE USER_ID(name) IS NULL;   -- already gone
DELETE @DropRoles WHERE USER_ID(name) IS NULL;

DECLARE @Steps TABLE (Seq int IDENTITY, Step nvarchar(200), Sql nvarchar(max));
DECLARE @db sysname = DB_NAME();

-- 3.1 Database owner: must be a login that exists (a retired domain account breaks dbo)
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @db AND SUSER_SNAME(owner_sid) = @DbOwner)
    INSERT @Steps VALUES (N'Database owner -> ' + @DbOwner,
        N'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@db) + N' TO ' + QUOTENAME(@DbOwner) + N';');

-- 3.2 SQL Agent jobs owned by a login that no longer resolves, or by a retired domain account
INSERT @Steps
SELECT N'Job owner -> ' + @DbOwner + N': ' + j.name,
       N'EXEC msdb.dbo.sp_update_job @job_id = ''' + CONVERT(nvarchar(36), j.job_id) + N''', @owner_login_name = N'''
       + REPLACE(@DbOwner, N'''', N'''''') + N''';'
FROM msdb.dbo.sysjobs AS j
WHERE SUSER_SNAME(j.owner_sid) IS NULL OR SUSER_SNAME(j.owner_sid) LIKE N'YELLOWCADDIS\%';

-- 3.3 Schemas, roles and objects owned by anything being dropped -> dbo
INSERT @Steps
SELECT N'Schema owner -> dbo: ' + s.name, N'ALTER AUTHORIZATION ON SCHEMA::' + QUOTENAME(s.name) + N' TO dbo;'
FROM sys.schemas AS s
WHERE USER_NAME(s.principal_id) IN (SELECT name FROM @DropUsers UNION SELECT name FROM @DropRoles);

INSERT @Steps
SELECT N'Role owner -> dbo: ' + r.name, N'ALTER AUTHORIZATION ON ROLE::' + QUOTENAME(r.name) + N' TO dbo;'
FROM sys.database_principals AS r
WHERE r.type = 'R' AND USER_NAME(r.owning_principal_id) IN (SELECT name FROM @DropUsers UNION SELECT name FROM @DropRoles)
  AND r.name NOT IN (SELECT name FROM @DropRoles);

INSERT @Steps
SELECT N'Object owner -> schema owner: ' + OBJECT_SCHEMA_NAME(o.object_id) + N'.' + o.name,
       N'ALTER AUTHORIZATION ON OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + N'.' + QUOTENAME(o.name) + N' TO SCHEMA OWNER;'
FROM sys.objects AS o
WHERE o.principal_id IS NOT NULL AND USER_NAME(o.principal_id) IN (SELECT name FROM @DropUsers UNION SELECT name FROM @DropRoles);

-- 3.4 The application role
IF USER_ID(N'FitnessApp') IS NULL
    INSERT @Steps VALUES (N'Create role FitnessApp', N'CREATE ROLE FitnessApp AUTHORIZATION dbo;');
INSERT @Steps VALUES (N'Grant FitnessApp read/write on dbo',
    N'GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO FitnessApp;');

-- 3.5 Service user: FitnessApp only
IF NOT EXISTS (SELECT 1 FROM sys.database_role_members
               WHERE role_principal_id = USER_ID(N'FitnessApp') AND member_principal_id = USER_ID(@ServiceUser))
    INSERT @Steps VALUES (N'Add ' + @ServiceUser + N' to FitnessApp',
        N'ALTER ROLE FitnessApp ADD MEMBER ' + QUOTENAME(@ServiceUser) + N';');
INSERT @Steps
SELECT N'Remove ' + @ServiceUser + N' from ' + r.name,
       N'ALTER ROLE ' + QUOTENAME(r.name) + N' DROP MEMBER ' + QUOTENAME(@ServiceUser) + N';'
FROM sys.database_role_members AS rm
JOIN sys.database_principals AS r ON r.principal_id = rm.role_principal_id
WHERE rm.member_principal_id = USER_ID(@ServiceUser) AND r.name <> N'FitnessApp';

-- 3.6 db_owner: admin only (members that are being dropped go with their user)
INSERT @Steps
SELECT N'Remove ' + m.name + N' from db_owner',
       N'ALTER ROLE db_owner DROP MEMBER ' + QUOTENAME(m.name) + N';'
FROM sys.database_role_members AS rm
JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
WHERE rm.role_principal_id = USER_ID(N'db_owner')
  AND m.name NOT IN (@AdminUser, @ServiceUser, N'dbo')
  AND m.name NOT IN (SELECT name FROM @DropUsers);

-- 3.7 Legacy roles: empty them, then drop
INSERT @Steps
SELECT N'Remove ' + m.name + N' from ' + r.name,
       N'ALTER ROLE ' + QUOTENAME(r.name) + N' DROP MEMBER ' + QUOTENAME(m.name) + N';'
FROM @DropRoles AS d
JOIN sys.database_principals AS r ON r.name = d.name
JOIN sys.database_role_members AS rm ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
WHERE m.name <> @ServiceUser;   -- already handled in 3.5
INSERT @Steps SELECT N'Drop role ' + name, N'DROP ROLE ' + QUOTENAME(name) + N';' FROM @DropRoles;

-- 3.8 Legacy users
INSERT @Steps SELECT N'Drop user ' + name, N'DROP USER ' + QUOTENAME(name) + N';' FROM @DropUsers;

-- 3.9 Server logins of the retired domain (they cannot authenticate anywhere any more)
INSERT @Steps
SELECT N'Drop login ' + sp.name, N'DROP LOGIN ' + QUOTENAME(sp.name) + N';'
FROM sys.server_principals AS sp
WHERE sp.type IN ('U', 'G') AND sp.name LIKE N'YELLOWCADDIS\%';

------------------------------------------------------------------------------------------------------------------
-- Part 4: preview or apply
------------------------------------------------------------------------------------------------------------------
PRINT N'';
PRINT CASE WHEN @Apply = 1 THEN N'== Applying' ELSE N'== Preview (set @Apply = 1 to make these changes)' END;

DECLARE @seq int, @step nvarchar(200), @sql nvarchar(max);
DECLARE s CURSOR LOCAL FAST_FORWARD FOR SELECT Seq, Step, Sql FROM @Steps ORDER BY Seq;
OPEN s;
FETCH NEXT FROM s INTO @seq, @step, @sql;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT CONCAT(@seq, N'. ', @step);
    PRINT N'   ' + @sql;
    IF @Apply = 1 EXEC sp_executesql @sql;   -- an error stops the script here; fix it and re-run
    FETCH NEXT FROM s INTO @seq, @step, @sql;
END;
CLOSE s; DEALLOCATE s;

PRINT N'';
PRINT N'SQL logins of dropped users (FitnessUser, ElevatedUser, StandardUser, RouteService, ...) are NOT dropped here.';
PRINT N'Check that no other database on the server uses them, then DROP LOGIN them in master.';

------------------------------------------------------------------------------------------------------------------
-- Part 5: verify (after applying)
------------------------------------------------------------------------------------------------------------------
IF @Apply = 1
BEGIN
    PRINT N'== Permissions of ' + @ServiceUser + N' on schema dbo (expect SELECT, INSERT, UPDATE, DELETE, plus REFERENCES if granted elsewhere)';
    EXECUTE AS USER = @ServiceUser;
    SELECT permission_name FROM fn_my_permissions(N'dbo', N'SCHEMA') ORDER BY permission_name;
    SELECT HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CREATE TABLE') AS CanCreateTable,      -- expect 0
           HAS_PERMS_BY_NAME(N'archive', N'SCHEMA', N'SELECT')         AS CanReadArchive,      -- expect 0 (or NULL)
           IS_ROLEMEMBER(N'db_owner')                                  AS IsDbOwner;           -- expect 0
    REVERT;
END;
GO

SET NOEXEC OFF;
GO
