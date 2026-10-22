-- 00_usage_audit.sql -- run BEFORE archiving to confirm the procedures really are unused, and to see who has access.
-- Read-only. Updated 2026-10-14: the YELLOWCADDIS domain no longer exists, so its accounts are reported as
-- "retired domain - drop" rather than as orphans to re-link. 04_permissions.sql does the clean-up.

-- (a) Plan-cache evidence: any proc executed since the last restart shows up here.
SELECT OBJECT_SCHEMA_NAME(ps.object_id) AS [schema], OBJECT_NAME(ps.object_id) AS proc_name, ps.execution_count, ps.last_execution_time
FROM sys.dm_exec_procedure_stats ps WHERE ps.database_id = DB_ID() ORDER BY ps.last_execution_time DESC;

-- (b) Cross-object references inside the database (what still depends on what).
SELECT referencing_object = OBJECT_SCHEMA_NAME(d.referencing_id)+'.'+OBJECT_NAME(d.referencing_id),
       referenced_object  = ISNULL(d.referenced_schema_name,'dbo')+'.'+d.referenced_entity_name, d.referenced_class_desc
FROM sys.sql_expression_dependencies d
WHERE d.referencing_id IN (SELECT object_id FROM sys.objects WHERE type IN ('P','FN','V'))
ORDER BY 1,2;

-- (c) Permissions actually granted, at every level (the dacpac contained none).
SELECT pr.name AS principal, pe.class_desc, pe.permission_name, pe.state_desc,
       CASE pe.class WHEN 0 THEN DB_NAME()
                     WHEN 1 THEN OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id)
                     WHEN 3 THEN SCHEMA_NAME(pe.major_id)
                     ELSE CONVERT(nvarchar(20), pe.major_id) END AS securable
FROM sys.database_permissions pe JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name NOT IN ('public', 'guest') OR pe.class <> 1
ORDER BY pr.name, pe.class, securable;

-- (d) Users and their status: retired domain accounts, orphans (no login on this server), role memberships.
SELECT dp.name, dp.type_desc, sp.name AS login_name,
       CASE WHEN dp.name LIKE N'YELLOWCADDIS\%'                      THEN 'retired domain - drop'
            WHEN dp.type IN ('S','U','G') AND dp.authentication_type <> 0
                 AND sp.sid IS NULL                                   THEN 'orphaned - re-link or drop'
            ELSE '' END AS status,
       STUFF((SELECT ', ' + r.name FROM sys.database_role_members rm
              JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
              WHERE rm.member_principal_id = dp.principal_id FOR XML PATH('')), 1, 2, '') AS member_of
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
WHERE dp.principal_id > 4 AND dp.is_fixed_role = 0
ORDER BY status DESC, dp.type_desc, dp.name;

-- (e) Owners that must be live logins: the database, schemas, roles and SQL Agent jobs.
SELECT 'database' AS kind, name, ISNULL(SUSER_SNAME(owner_sid), '<unresolvable>') AS owner FROM sys.databases WHERE name = DB_NAME()
UNION ALL SELECT 'schema', name, USER_NAME(principal_id) FROM sys.schemas WHERE principal_id > 4 AND principal_id < 16384
UNION ALL SELECT 'role', name, USER_NAME(owning_principal_id) FROM sys.database_principals WHERE type = 'R' AND is_fixed_role = 0
UNION ALL SELECT 'job', name, ISNULL(SUSER_SNAME(owner_sid), '<unresolvable>') FROM msdb.dbo.sysjobs;

-- (f) Server logins from the retired domain.
SELECT name, type_desc, create_date FROM sys.server_principals WHERE type IN ('U','G') AND name LIKE N'YELLOWCADDIS\%';

-- (g) Optional: 30-day Extended Events session to catch any caller of a dbo procedure.
/*
CREATE EVENT SESSION [FitnessProcUsage] ON SERVER
ADD EVENT sqlserver.module_end (ACTION(sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.username)
    WHERE sqlserver.database_name = N'Fitness' AND object_type = 8272)  -- 8272 = stored procedure
ADD TARGET package0.event_file (SET filename = N'FitnessProcUsage.xel', max_file_size = 50)
WITH (STARTUP_STATE = ON);
ALTER EVENT SESSION [FitnessProcUsage] ON SERVER STATE = START;
*/
