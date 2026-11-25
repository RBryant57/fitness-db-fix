-- 05_copy_archive_to_database.sql
-- Copies everything in Fitness's [archive] schema into a separate database, FitnessArchive, so that
-- 06_drop_archive_schema.sql can then remove the schema from Fitness.
--
--   Tables (the six legacy *GPX tables, HRZones, HRZoneTime, BikeHistory and ArchiveLog): structure and every row,
--     with their primary keys, unique constraints, indexes, defaults, checks and the foreign keys between them.
--     Identity values are kept.
--   Procedures and functions (111 + 3): the definitions exactly as they are in Fitness, created with the same
--     QUOTED_IDENTIFIER and ANSI_NULLS settings. Reference only: they read Fitness tables that are not in
--     FitnessArchive, so they are not meant to run there.
--
-- In FitnessArchive everything is in dbo: archive.TrainingRideGPX becomes FitnessArchive.dbo.TrainingRideGPX, and the
-- procedure definitions (written for dbo) are unchanged.
--
-- @Apply = 0 (default): lists what would be copied and, if FitnessArchive already exists, compares it with Fitness.
-- @Apply = 1: creates FitnessArchive if needed (owner sa, compatibility level 170), copies whatever is not there yet in
--   one transaction, compares every object and every row with Fitness, and commits only if everything matches.
-- Safe to run again: objects already in FitnessArchive are not copied twice; they are compared again.
-- Undo (before 06 has run): DROP DATABASE FitnessArchive;
--
-- sqlcmd -S <server> -d Fitness -E -I -b -i 05_copy_archive_to_database.sql
-- or:    .\Run-FitnessScripts.ps1 -Phase ArchiveDb [-Apply]

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply  bit     = 0;                  -- 0 = report only, 1 = create and copy
DECLARE @Target sysname = N'FitnessArchive';

DECLARE @Exec nvarchar(300) = QUOTENAME(@Target) + N'.sys.sp_executesql';   -- runs a statement inside the target
DECLARE @sql nvarchar(max), @name sysname, @type char(2), @def nvarchar(max), @qi bit, @an bit, @cols nvarchar(max);
DECLARE @Step nvarchar(400) = N'', @Msg nvarchar(2048);
DECLARE @s bigint, @t bigint, @m bigint, @e bigint;

IF SCHEMA_ID(N'archive') IS NULL
BEGIN
    RAISERROR(N'Fitness has no [archive] schema. Nothing to copy.', 16, 1);
    RETURN;
END;

---------------------------------------------------------------------------------------------------------------------
-- What is in [archive]
---------------------------------------------------------------------------------------------------------------------
DECLARE @Other nvarchar(2000) = STUFF((
    SELECT N', ' + o.name + N' (' + o.type_desc + N')'
    FROM sys.objects AS o
    WHERE o.schema_id = SCHEMA_ID(N'archive')
      AND ((o.parent_object_id = 0 AND o.type NOT IN ('U', 'P', 'FN', 'IF', 'TF', 'V')) OR o.type = 'TR')
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(2000)'), 1, 2, N'');
IF @Other IS NOT NULL
BEGIN
    RAISERROR(N'[archive] has objects this script does not copy: %s. Nothing was changed.', 16, 1, @Other);
    RETURN;
END;

DECLARE @Src TABLE (Seq int IDENTITY(1, 1), Name sysname, Type char(2), TypeDesc nvarchar(60), [Rows] bigint NULL,
                    QI bit NULL, AN bit NULL, Def nvarchar(max) NULL);
INSERT @Src (Name, Type, TypeDesc, [Rows], QI, AN, Def)
SELECT o.name, o.type, o.type_desc,
       (SELECT SUM(p.row_count) FROM sys.dm_db_partition_stats AS p WHERE p.object_id = o.object_id AND p.index_id IN (0, 1)),
       m.uses_quoted_identifier, m.uses_ansi_nulls, m.definition
FROM sys.objects AS o
LEFT JOIN sys.sql_modules AS m ON m.object_id = o.object_id
WHERE o.schema_id = SCHEMA_ID(N'archive') AND o.parent_object_id = 0 AND o.type IN ('U', 'FN', 'IF', 'TF', 'V', 'P')
ORDER BY CASE o.type WHEN 'U' THEN 1 WHEN 'V' THEN 3 WHEN 'P' THEN 4 ELSE 2 END, o.name;

IF EXISTS (SELECT 1 FROM @Src WHERE Type <> 'U' AND Def IS NULL)
BEGIN
    RAISERROR(N'[archive] has an encrypted procedure or function; its definition cannot be copied. Nothing was changed.', 16, 1);
    RETURN;
END;

IF EXISTS (SELECT 1 FROM sys.foreign_keys AS fk
           WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'archive' AND OBJECT_SCHEMA_NAME(fk.referenced_object_id) <> N'archive')
    PRINT N'Note: foreign keys from [archive] tables to dbo tables are not copied (those dbo tables are not in ' + @Target + N').';

-- Objects already in the target (dbo, user objects only)
DECLARE @Tgt TABLE (Name sysname, Type char(2), QI bit NULL, AN bit NULL, Def nvarchar(max) NULL);
DECLARE @TgtQuery nvarchar(max) = N'
    SELECT o.name, o.type, m.uses_quoted_identifier, m.uses_ansi_nulls, m.definition
    FROM sys.objects AS o LEFT JOIN sys.sql_modules AS m ON m.object_id = o.object_id
    WHERE o.schema_id = SCHEMA_ID(N''dbo'') AND o.parent_object_id = 0 AND o.is_ms_shipped = 0
      AND o.type IN (''U'', ''FN'', ''IF'', ''TF'', ''V'', ''P'');';
IF DB_ID(@Target) IS NOT NULL INSERT @Tgt EXEC @Exec @TgtQuery;

IF EXISTS (SELECT 1 FROM @Src AS s JOIN @Tgt AS t ON t.Name = s.Name AND t.Type <> s.Type)
BEGIN
    RAISERROR(N'%s already has an object with the name of an [archive] object but of a different type (see DIFFERENT TYPE below).', 10, 1, @Target);
END;

---------------------------------------------------------------------------------------------------------------------
-- Create the database (cannot be part of the transaction)
---------------------------------------------------------------------------------------------------------------------
IF @Apply = 1 AND DB_ID(@Target) IS NULL
BEGIN
    SET @sql = N'CREATE DATABASE ' + QUOTENAME(@Target) + N';';                              PRINT @sql; EXEC (@sql);
    SET @sql = N'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@Target) + N' TO sa;';        PRINT @sql; EXEC (@sql);
    SET @sql = N'ALTER DATABASE ' + QUOTENAME(@Target) + N' SET COMPATIBILITY_LEVEL = 170;';  PRINT @sql; EXEC (@sql);
END;

BEGIN TRY
    IF @Apply = 1
    BEGIN
        BEGIN TRANSACTION;

        -------------------------------------------------------------------------------------------------------------
        -- 1. Tables and their rows
        -------------------------------------------------------------------------------------------------------------
        DECLARE @New TABLE (Name sysname PRIMARY KEY);

        DECLARE tc CURSOR LOCAL FAST_FORWARD FOR
            SELECT s.Name FROM @Src AS s
            WHERE s.Type = 'U' AND NOT EXISTS (SELECT 1 FROM @Tgt AS t WHERE t.Name = s.Name)
            ORDER BY s.Seq;
        OPEN tc; FETCH NEXT FROM tc INTO @name;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Step = N'table ' + @name;
            SET @sql = N'SELECT * INTO ' + QUOTENAME(@Target) + N'.dbo.' + QUOTENAME(@name)
                     + N' FROM archive.' + QUOTENAME(@name) + N';';
            PRINT @sql; EXEC sp_executesql @sql;
            INSERT @New VALUES (@name);
            FETCH NEXT FROM tc INTO @name;
        END;
        CLOSE tc; DEALLOCATE tc;

        -- Keys, indexes, defaults, checks and foreign keys of the tables just copied, from Fitness's catalog
        DECLARE @Ddl TABLE (Id int IDENTITY(1, 1), Ord int, Stmt nvarchar(max));

        INSERT @Ddl (Ord, Stmt)
        SELECT CASE WHEN i.is_primary_key = 1 THEN 1 WHEN i.is_unique_constraint = 1 THEN 2 ELSE 3 END,
               CASE WHEN i.is_primary_key = 1 OR i.is_unique_constraint = 1
                    THEN N'ALTER TABLE dbo.' + QUOTENAME(t.name) + N' ADD CONSTRAINT ' + QUOTENAME(i.name)
                         + CASE WHEN i.is_primary_key = 1 THEN N' PRIMARY KEY ' ELSE N' UNIQUE ' END
                         + CASE WHEN i.type = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END + N' (' + k.Cols + N');'
                    ELSE N'CREATE ' + CASE WHEN i.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END
                         + CASE WHEN i.type = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END
                         + N' INDEX ' + QUOTENAME(i.name) + N' ON dbo.' + QUOTENAME(t.name) + N' (' + k.Cols + N')'
                         + ISNULL(N' INCLUDE (' + inc.Cols + N')', N'')
                         + ISNULL(N' WHERE ' + i.filter_definition, N'') + N';'
               END
        FROM sys.indexes AS i
        JOIN sys.tables AS t ON t.object_id = i.object_id
        CROSS APPLY (SELECT STUFF((
                        SELECT N', ' + QUOTENAME(c.name) + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N'' END
                        FROM sys.index_columns AS ic
                        JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal > 0
                        ORDER BY ic.key_ordinal
                        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS Cols) AS k
        CROSS APPLY (SELECT STUFF((
                        SELECT N', ' + QUOTENAME(c.name)
                        FROM sys.index_columns AS ic
                        JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                        ORDER BY ic.index_column_id
                        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS Cols) AS inc
        WHERE t.schema_id = SCHEMA_ID(N'archive') AND t.name IN (SELECT Name FROM @New)
          AND i.type IN (1, 2) AND i.is_hypothetical = 0;

        INSERT @Ddl (Ord, Stmt)
        SELECT 4, N'ALTER TABLE dbo.' + QUOTENAME(OBJECT_NAME(d.parent_object_id)) + N' ADD CONSTRAINT ' + QUOTENAME(d.name)
                  + N' DEFAULT ' + d.definition + N' FOR ' + QUOTENAME(c.name) + N';'
        FROM sys.default_constraints AS d
        JOIN sys.columns AS c ON c.object_id = d.parent_object_id AND c.column_id = d.parent_column_id
        WHERE d.schema_id = SCHEMA_ID(N'archive') AND OBJECT_NAME(d.parent_object_id) IN (SELECT Name FROM @New);

        INSERT @Ddl (Ord, Stmt)
        SELECT 5, N'ALTER TABLE dbo.' + QUOTENAME(OBJECT_NAME(k.parent_object_id))
                  + CASE WHEN k.is_not_trusted = 1 THEN N' WITH NOCHECK' ELSE N' WITH CHECK' END
                  + N' ADD CONSTRAINT ' + QUOTENAME(k.name) + N' CHECK ' + k.definition + N';'
                  + CASE WHEN k.is_disabled = 1
                         THEN N' ALTER TABLE dbo.' + QUOTENAME(OBJECT_NAME(k.parent_object_id)) + N' NOCHECK CONSTRAINT ' + QUOTENAME(k.name) + N';'
                         ELSE N'' END
        FROM sys.check_constraints AS k
        WHERE k.schema_id = SCHEMA_ID(N'archive') AND OBJECT_NAME(k.parent_object_id) IN (SELECT Name FROM @New);

        INSERT @Ddl (Ord, Stmt)
        SELECT 6, N'ALTER TABLE dbo.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
                  + CASE WHEN fk.is_not_trusted = 1 THEN N' WITH NOCHECK' ELSE N' WITH CHECK' END
                  + N' ADD CONSTRAINT ' + QUOTENAME(fk.name) + N' FOREIGN KEY (' + pc.Cols + N') REFERENCES dbo.'
                  + QUOTENAME(OBJECT_NAME(fk.referenced_object_id)) + N' (' + rc.Cols + N')'
                  + CASE fk.delete_referential_action WHEN 1 THEN N' ON DELETE CASCADE' WHEN 2 THEN N' ON DELETE SET NULL'
                                                      WHEN 3 THEN N' ON DELETE SET DEFAULT' ELSE N'' END
                  + CASE fk.update_referential_action WHEN 1 THEN N' ON UPDATE CASCADE' WHEN 2 THEN N' ON UPDATE SET NULL'
                                                      WHEN 3 THEN N' ON UPDATE SET DEFAULT' ELSE N'' END + N';'
        FROM sys.foreign_keys AS fk
        CROSS APPLY (SELECT STUFF((
                        SELECT N', ' + QUOTENAME(COL_NAME(fkc.parent_object_id, fkc.parent_column_id))
                        FROM sys.foreign_key_columns AS fkc WHERE fkc.constraint_object_id = fk.object_id
                        ORDER BY fkc.constraint_column_id
                        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS Cols) AS pc
        CROSS APPLY (SELECT STUFF((
                        SELECT N', ' + QUOTENAME(COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id))
                        FROM sys.foreign_key_columns AS fkc WHERE fkc.constraint_object_id = fk.object_id
                        ORDER BY fkc.constraint_column_id
                        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') AS Cols) AS rc
        WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'archive' AND OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'archive'
          AND OBJECT_NAME(fk.parent_object_id) IN (SELECT Name FROM @New);

        DECLARE dc CURSOR LOCAL FAST_FORWARD FOR SELECT Stmt FROM @Ddl ORDER BY Ord, Id;
        OPEN dc; FETCH NEXT FROM dc INTO @sql;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Step = LEFT(@sql, 400);
            PRINT @sql; EXEC @Exec @sql;
            FETCH NEXT FROM dc INTO @sql;
        END;
        CLOSE dc; DEALLOCATE dc;

        -------------------------------------------------------------------------------------------------------------
        -- 2. Functions, views and procedures, with their original SET options
        -------------------------------------------------------------------------------------------------------------
        DECLARE mc CURSOR LOCAL FAST_FORWARD FOR
            SELECT s.Name, s.Type, s.Def, s.QI, s.AN FROM @Src AS s
            WHERE s.Type <> 'U' AND NOT EXISTS (SELECT 1 FROM @Tgt AS t WHERE t.Name = s.Name)
            ORDER BY s.Seq;
        OPEN mc; FETCH NEXT FROM mc INTO @name, @type, @def, @qi, @an;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Step = N'module ' + @name;
            -- QUOTED_IDENTIFIER and ANSI_NULLS are set in the outer batch, so the inner EXEC parses and stores the
            -- definition with them; they revert when the batch ends.
            SET @sql = N'SET QUOTED_IDENTIFIER ' + CASE WHEN @qi = 1 THEN N'ON' ELSE N'OFF' END
                     + N'; SET ANSI_NULLS ' + CASE WHEN @an = 1 THEN N'ON' ELSE N'OFF' END
                     + N'; EXEC (@d);';
            EXEC @Exec @sql, N'@d nvarchar(max)', @d = @def;
            PRINT N'Created ' + RTRIM(@type) + N' dbo.' + @name;
            FETCH NEXT FROM mc INTO @name, @type, @def, @qi, @an;
        END;
        CLOSE mc; DEALLOCATE mc;
        SET @Step = N'comparison';
    END;

    -----------------------------------------------------------------------------------------------------------------
    -- 3. Compare FitnessArchive with Fitness.archive: every object, every row, every definition
    -----------------------------------------------------------------------------------------------------------------
    DECLARE @Rows TABLE (Name sysname PRIMARY KEY, SrcRows bigint, TgtRows bigint, Missing bigint, Extra bigint, Skipped int);
    DELETE @Tgt;
    IF DB_ID(@Target) IS NOT NULL
    BEGIN
        INSERT @Tgt EXEC @Exec @TgtQuery;

        DECLARE rc CURSOR LOCAL FAST_FORWARD FOR
            SELECT s.Name FROM @Src AS s JOIN @Tgt AS t ON t.Name = s.Name AND t.Type = 'U' WHERE s.Type = 'U';
        OPEN rc; FETCH NEXT FROM rc INTO @name;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- columns EXCEPT can compare (text/ntext/image/xml/spatial cannot; rowversion is regenerated by a copy)
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
            INSERT @Rows VALUES (@name, @s, @t, @m, @e,
                (SELECT COUNT(*) FROM sys.columns AS c WHERE c.object_id = OBJECT_ID(N'archive.' + QUOTENAME(@name))
                   AND TYPE_NAME(c.system_type_id) IN (N'text', N'ntext', N'image', N'xml', N'geography', N'geometry', N'timestamp')));
            FETCH NEXT FROM rc INTO @name;
        END;
        CLOSE rc; DEALLOCATE rc;
    END;

    DECLARE @Result TABLE (Seq int, Name sysname, ObjectType nvarchar(60), SourceRows bigint, TargetRows bigint, Result nvarchar(200));
    INSERT @Result
    SELECT s.Seq, s.Name, s.TypeDesc, COALESCE(r.SrcRows, s.[Rows]), r.TgtRows,
           CASE WHEN t.Name IS NULL THEN CASE WHEN @Apply = 1 THEN N'MISSING' ELSE N'to copy' END
                WHEN t.Type <> s.Type THEN N'DIFFERENT TYPE'
                -- ArchiveLog may have more rows in the target: 05 and 06 add their own entries there
                WHEN s.Type = 'U' AND r.Missing > 0 THEN CONCAT(N'ROWS DIFFER: ', r.Missing, N' source row(s) not in target')
                WHEN s.Type = 'U' AND s.Name <> N'ArchiveLog' AND (r.Extra > 0 OR r.TgtRows <> r.SrcRows)
                     THEN CONCAT(N'ROWS DIFFER: ', r.TgtRows, N' in target, ', r.SrcRows, N' in source')
                WHEN s.Type = 'U' AND s.Name = N'ArchiveLog' AND r.TgtRows < r.SrcRows THEN N'ROWS DIFFER'
                WHEN s.Type <> 'U' AND (t.Def IS NULL OR t.Def COLLATE Latin1_General_BIN2 <> s.Def COLLATE Latin1_General_BIN2)
                     THEN N'DIFFERENT DEFINITION'
                WHEN s.Type <> 'U' AND (t.QI <> s.QI OR t.AN <> s.AN) THEN N'DIFFERENT SET OPTIONS'
                WHEN s.Type = 'U' AND r.Skipped > 0 THEN CONCAT(N'OK (', r.Skipped, N' column(s) counted, not compared)')
                WHEN s.Name = N'ArchiveLog' AND r.TgtRows > r.SrcRows THEN CONCAT(N'OK (+', r.TgtRows - r.SrcRows, N' log entries)')
                ELSE N'OK' END
    FROM @Src AS s
    LEFT JOIN @Tgt AS t ON t.Name = s.Name
    LEFT JOIN @Rows AS r ON r.Name = s.Name;

    SELECT Name, ObjectType, SourceRows, TargetRows, Result FROM @Result ORDER BY Seq;

    DECLARE @Tables int    = (SELECT COUNT(*) FROM @Src WHERE Type = 'U'),
            @Modules int   = (SELECT COUNT(*) FROM @Src WHERE Type <> 'U'),
            @RowsSrc bigint = (SELECT SUM(SourceRows) FROM @Result),
            @Ok int        = (SELECT COUNT(*) FROM @Result WHERE Result LIKE N'OK%'),
            @ToCopy int    = (SELECT COUNT(*) FROM @Result WHERE Result = N'to copy'),
            @Bad int       = (SELECT COUNT(*) FROM @Result WHERE Result NOT LIKE N'OK%' AND Result <> N'to copy');

    IF @Apply = 1
    BEGIN
        IF @Bad > 0
        BEGIN
            SET @Msg = CONCAT(@Bad, N' object(s) in ', @Target, N' do not match Fitness.archive (see the list). Everything copied by this run was rolled back.');
            THROW 50000, @Msg, 1;
        END;
        IF EXISTS (SELECT 1 FROM @Tgt WHERE Name = N'ArchiveLog' AND Type = 'U')
        BEGIN
            SET @sql = N'INSERT dbo.ArchiveLog (Note) VALUES (@n);';
            SET @Msg = CONCAT(N'05: copied Fitness.archive from ', @@SERVERNAME, N': ', @Tables, N' tables, ',
                              @Modules, N' procedures and functions. Compared: all match.');
            EXEC @Exec @sql, N'@n nvarchar(400)', @n = @Msg;
        END;
        COMMIT;
        PRINT CONCAT(N'Done. All ', @Ok, N' objects in ', @Target, N' match Fitness.archive (', @Tables, N' tables with ',
                     @RowsSrc, N' rows, ', @Modules, N' procedures and functions).');
        PRINT N'Next: extract the FitnessArchive SQL project, then -Phase Drop (preview).';
    END
    ELSE IF DB_ID(@Target) IS NULL
        PRINT CONCAT(N'Nothing changed. ', @Target, N' does not exist yet. Set @Apply = 1 to create it and copy ',
                     @Tables, N' tables and ', @Modules, N' procedures and functions.');
    ELSE IF @Bad > 0
        PRINT CONCAT(N'Nothing changed. ', @Bad, N' object(s) in ', @Target, N' do not match; fix them before -Phase Drop.');
    ELSE IF @ToCopy > 0
        PRINT CONCAT(N'Nothing changed. ', @ToCopy, N' object(s) still to copy; set @Apply = 1.');
    ELSE
        PRINT CONCAT(N'Nothing changed. All ', @Ok, N' objects in ', @Target, N' match Fitness.archive.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    IF @Step <> N'' PRINT N'Failed at: ' + @Step;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
