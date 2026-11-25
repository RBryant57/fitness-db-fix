-- 06_drop_archive_schema.sql
-- Drops the [archive] schema, and everything in it, from Fitness once 05_copy_archive_to_database.sql has copied it
-- to FitnessArchive. Replaces 03_drop_archived_objects.sql and 03b_drop_gpx_tables.sql: nothing is lost, because
-- FitnessArchive keeps every table, row and definition.
--
-- It refuses (and changes nothing) unless:
--   * FitnessArchive has every [archive] object: each table with the same rows, each procedure and function with the
--     same definition and SET options (the same comparison as 05);
--   * nothing outside [archive] in Fitness refers to an [archive] object (code or foreign key).
--
-- Before @Apply = 1: back up Fitness and FitnessArchive, and add FitnessArchive to your backup jobs.
-- There is no rollback script. To get an object back, copy it from FitnessArchive.
--
-- @Apply = 0 (default) checks and lists what would be dropped; @Apply = 1 drops it in one transaction.
-- sqlcmd -S <server> -d Fitness -E -I -b -i 06_drop_archive_schema.sql
-- or:    .\Run-FitnessScripts.ps1 -Phase Drop [-Apply]

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply  bit     = 0;                  -- 0 = check only, 1 = drop
DECLARE @Target sysname = N'FitnessArchive';

DECLARE @Exec nvarchar(300) = QUOTENAME(@Target) + N'.sys.sp_executesql';
DECLARE @sql nvarchar(max), @name sysname, @cols nvarchar(max), @Msg nvarchar(2048);
DECLARE @s bigint, @t bigint, @m bigint, @e bigint;

IF SCHEMA_ID(N'archive') IS NULL
BEGIN
    PRINT N'Fitness has no [archive] schema. Nothing to drop.';
    RETURN;
END;
IF DB_ID(@Target) IS NULL
BEGIN
    RAISERROR(N'%s does not exist. Run 05_copy_archive_to_database.sql (-Phase ArchiveDb -Apply) first. Nothing was changed.', 16, 1, @Target);
    RETURN;
END;

---------------------------------------------------------------------------------------------------------------------
-- 1. Nothing outside [archive] may depend on it
---------------------------------------------------------------------------------------------------------------------
DECLARE @Users nvarchar(4000) = STUFF((
    SELECT DISTINCT N', ' + ISNULL(OBJECT_SCHEMA_NAME(d.referencing_id) + N'.', N'') + ISNULL(OBJECT_NAME(d.referencing_id), N'?')
                  + N' -> archive.' + d.referenced_entity_name
    FROM sys.sql_expression_dependencies AS d
    WHERE (d.referenced_schema_name = N'archive'
           OR d.referenced_id IN (SELECT object_id FROM sys.objects WHERE schema_id = SCHEMA_ID(N'archive')))
      AND ISNULL(OBJECT_SCHEMA_NAME(d.referencing_id), N'') <> N'archive'
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(4000)'), 1, 2, N'');
IF @Users IS NOT NULL
BEGIN
    RAISERROR(N'Code outside [archive] still refers to it: %s. Nothing was changed.', 16, 1, @Users);
    RETURN;
END;

DECLARE @Fks nvarchar(4000) = STUFF((
    SELECT N', ' + fk.name
    FROM sys.foreign_keys AS fk
    WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'archive' AND OBJECT_SCHEMA_NAME(fk.parent_object_id) <> N'archive'
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(4000)'), 1, 2, N'');
IF @Fks IS NOT NULL
BEGIN
    RAISERROR(N'Foreign keys outside [archive] reference it: %s. Nothing was changed.', 16, 1, @Fks);
    RETURN;
END;

---------------------------------------------------------------------------------------------------------------------
-- 2. FitnessArchive must hold an identical copy (same comparison as 05)
---------------------------------------------------------------------------------------------------------------------
DECLARE @Src TABLE (Seq int IDENTITY(1, 1), Name sysname, Type char(2), TypeDesc nvarchar(60),
                    QI bit NULL, AN bit NULL, Def nvarchar(max) NULL);
INSERT @Src (Name, Type, TypeDesc, QI, AN, Def)
SELECT o.name, o.type, o.type_desc, m.uses_quoted_identifier, m.uses_ansi_nulls, m.definition
FROM sys.objects AS o
LEFT JOIN sys.sql_modules AS m ON m.object_id = o.object_id
WHERE o.schema_id = SCHEMA_ID(N'archive') AND o.parent_object_id = 0
ORDER BY CASE o.type WHEN 'P' THEN 1 WHEN 'V' THEN 2 WHEN 'U' THEN 4 ELSE 3 END, o.name;

DECLARE @Tgt TABLE (Name sysname, Type char(2), QI bit NULL, AN bit NULL, Def nvarchar(max) NULL);
INSERT @Tgt EXEC @Exec N'
    SELECT o.name, o.type, m.uses_quoted_identifier, m.uses_ansi_nulls, m.definition
    FROM sys.objects AS o LEFT JOIN sys.sql_modules AS m ON m.object_id = o.object_id
    WHERE o.schema_id = SCHEMA_ID(N''dbo'') AND o.parent_object_id = 0 AND o.is_ms_shipped = 0;';

DECLARE @Rows TABLE (Name sysname PRIMARY KEY, SrcRows bigint, TgtRows bigint, Missing bigint, Extra bigint);
DECLARE rc CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.Name FROM @Src AS s JOIN @Tgt AS t ON t.Name = s.Name AND t.Type = 'U' WHERE s.Type = 'U';
OPEN rc; FETCH NEXT FROM rc INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @cols = STUFF((
        SELECT N', ' + QUOTENAME(c.name)
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(N'archive.' + QUOTENAME(@name))
          AND TYPE_NAME(c.system_type_id) NOT IN (N'text', N'ntext', N'image', N'xml', N'geography', N'geometry', N'timestamp')
        ORDER BY c.column_id
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'');
    SET @sql = N'SELECT @s = COUNT_BIG(*) FROM archive.' + QUOTENAME(@name) + N';
                 SELECT @t = COUNT_BIG(*) FROM ' + QUOTENAME(@Target) + N'.dbo.' + QUOTENAME(@name) + N';
                 SELECT @m = COUNT_BIG(*) FROM (SELECT ' + @cols + N' FROM archive.' + QUOTENAME(@name)
               + N' EXCEPT SELECT ' + @cols + N' FROM ' + QUOTENAME(@Target) + N'.dbo.' + QUOTENAME(@name) + N') AS x;
                 SELECT @e = COUNT_BIG(*) FROM (SELECT ' + @cols + N' FROM ' + QUOTENAME(@Target) + N'.dbo.' + QUOTENAME(@name)
               + N' EXCEPT SELECT ' + @cols + N' FROM archive.' + QUOTENAME(@name) + N') AS x;';
    EXEC sp_executesql @sql, N'@s bigint OUTPUT, @t bigint OUTPUT, @m bigint OUTPUT, @e bigint OUTPUT',
         @s = @s OUTPUT, @t = @t OUTPUT, @m = @m OUTPUT, @e = @e OUTPUT;
    INSERT @Rows VALUES (@name, @s, @t, @m, @e);
    FETCH NEXT FROM rc INTO @name;
END;
CLOSE rc; DEALLOCATE rc;

DECLARE @Result TABLE (Seq int, Name sysname, Type char(2), ObjectType nvarchar(60), [Rows] bigint, Result nvarchar(200));
INSERT @Result
SELECT s.Seq, s.Name, s.Type, s.TypeDesc, r.SrcRows,
       CASE WHEN s.Type NOT IN ('U', 'P', 'FN', 'IF', 'TF', 'V') THEN N'NOT COPIED BY 05 (' + s.TypeDesc + N')'
            WHEN t.Name IS NULL THEN N'MISSING in ' + @Target
            WHEN t.Type <> s.Type THEN N'DIFFERENT TYPE in ' + @Target
            WHEN s.Type = 'U' AND r.Missing > 0 THEN CONCAT(N'ROWS DIFFER: ', r.Missing, N' row(s) not in ', @Target)
            WHEN s.Type = 'U' AND s.Name <> N'ArchiveLog' AND (r.Extra > 0 OR r.TgtRows <> r.SrcRows)
                 THEN CONCAT(N'ROWS DIFFER: ', r.TgtRows, N' in ', @Target, N', ', r.SrcRows, N' here')
            WHEN s.Type = 'U' AND r.TgtRows < r.SrcRows THEN N'ROWS DIFFER'
            WHEN s.Type <> 'U' AND (t.Def IS NULL OR t.Def COLLATE Latin1_General_BIN2 <> s.Def COLLATE Latin1_General_BIN2)
                 THEN N'DIFFERENT DEFINITION in ' + @Target
            WHEN s.Type <> 'U' AND (t.QI <> s.QI OR t.AN <> s.AN) THEN N'DIFFERENT SET OPTIONS in ' + @Target
            ELSE N'copy OK - will be dropped' END
FROM @Src AS s
LEFT JOIN @Tgt AS t ON t.Name = s.Name
LEFT JOIN @Rows AS r ON r.Name = s.Name;

SELECT N'archive.' + Name AS ArchiveObject, ObjectType, [Rows], Result FROM @Result ORDER BY Seq;

DECLARE @Bad int      = (SELECT COUNT(*) FROM @Result WHERE Result <> N'copy OK - will be dropped'),
        @Tables int   = (SELECT COUNT(*) FROM @Result WHERE Type = 'U'),
        @Modules int  = (SELECT COUNT(*) FROM @Result WHERE Type <> 'U'),
        @RowCount bigint = (SELECT SUM([Rows]) FROM @Result WHERE Type = 'U');

IF @Bad > 0
BEGIN
    RAISERROR(N'%d object(s) are not safely copied to %s (see the list). Run -Phase ArchiveDb -Apply and check its output. Nothing was dropped.', 16, 1, @Bad, @Target);
    RETURN;
END;

IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. All ', @Tables, N' tables (', @RowCount, N' rows) and ', @Modules,
                 N' procedures and functions are in ', @Target, N'. Back up both databases, then set @Apply = 1 to drop [archive].');
    RETURN;
END;

---------------------------------------------------------------------------------------------------------------------
-- 3. Drop: foreign keys between archive tables, then procedures, views, functions, tables, and the schema
---------------------------------------------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE f CURSOR LOCAL FAST_FORWARD FOR
        SELECT N'ALTER TABLE archive.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
        FROM sys.foreign_keys AS fk
        WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'archive';
    OPEN f; FETCH NEXT FROM f INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN PRINT @sql; EXEC sp_executesql @sql; FETCH NEXT FROM f INTO @sql; END;
    CLOSE f; DEALLOCATE f;

    DECLARE o CURSOR LOCAL FAST_FORWARD FOR
        SELECT N'DROP ' + CASE Type WHEN 'P' THEN N'PROCEDURE' WHEN 'V' THEN N'VIEW' WHEN 'U' THEN N'TABLE' ELSE N'FUNCTION' END
             + N' archive.' + QUOTENAME(Name) + N';'
        FROM @Result ORDER BY Seq;
    OPEN o; FETCH NEXT FROM o INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN PRINT @sql; EXEC sp_executesql @sql; FETCH NEXT FROM o INTO @sql; END;
    CLOSE o; DEALLOCATE o;

    PRINT N'DROP SCHEMA archive;';
    DROP SCHEMA archive;

    IF EXISTS (SELECT 1 FROM @Tgt WHERE Name = N'ArchiveLog' AND Type = 'U')
    BEGIN
        SET @Msg = CONCAT(N'06: dropped the archive schema from Fitness on ', @@SERVERNAME, N' (', @Tables, N' tables, ',
                          @RowCount, N' rows, ', @Modules, N' procedures and functions). This database is now the only copy.');
        EXEC @Exec N'INSERT dbo.ArchiveLog (Note) VALUES (@n);', N'@n nvarchar(400)', @n = @Msg;
    END;

    COMMIT;
    PRINT CONCAT(N'Done. [archive] is gone from Fitness; ', @Target, N' keeps all ', @Tables, N' tables and ', @Modules,
                 N' procedures and functions.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
