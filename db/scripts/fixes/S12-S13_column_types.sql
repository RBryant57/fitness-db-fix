-- S12-S13_column_types.sql
-- S13: calendar dates stored as datetime become date (Bike, BikeOnlyMiles, BikePart, LiftingSession, Maintenance,
--      MissedMiles, Shoe, Weight). S12: Bike.Name, BikeType.Name and RouteType.Name become nvarchar(50), like every
--      other name. (NonRideMiles.Date is already date. The nine activity tables change type through their rebuild
--      scripts, because their computed Duration columns depend on StartTime / EndTime: -Phase Duration -Apply.)
-- A time of day stored in one of these date columns is dropped. On the staging data of 2026-11-16 that affects
-- MissedMiles (93 rows), Weight (20), BikePart.EndDate (2), Bike.AcquisitionDate (1) and Shoe.RetireDate (1); the
-- preview lists the counts. A unique index on a converted column is checked for values that would collide.
-- Indexes, defaults, checks and user-created statistics on a converted column are dropped and recreated as they were (for example
-- UQ_Weight_Date and DF_MissedMiles_Date); the views are refreshed afterwards.
-- API: DateTime properties keep working (the time part is simply midnight). If the EF model was scaffolded, update
-- HasColumnType("datetime") -> "date" and IsUnicode(false) on the three names, or re-scaffold.
--
-- @Apply = 0 lists each column with what would change; @Apply = 1 converts them, in one transaction. Safe to re-run.
-- sqlcmd -S <server> -d Fitness -E -I -b -i S12-S13_column_types.sql

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CurrentDb sysname = DB_NAME();
IF @CurrentDb <> N'Fitness'
BEGIN
    RAISERROR(N'Connected to database %s, not Fitness. Nothing was changed.', 16, 1, @CurrentDb);
    SET NOEXEC ON;
END;
GO

DECLARE @Apply bit = 0;   -- 0 = list only, 1 = convert

DECLARE @Cols TABLE (Seq int IDENTITY PRIMARY KEY, Item nvarchar(5), TableName sysname, ColumnName sysname, NewType nvarchar(30),
                     BaseType sysname, CurType nvarchar(60) NULL, IsNullable bit NULL, TimeRows int NULL, Collisions int NULL,
                     State nvarchar(400) NULL);
INSERT @Cols (Item, TableName, ColumnName, NewType, BaseType) VALUES
    (N'S13', N'Bike', N'AcquisitionDate', N'date', N'date'),
    (N'S13', N'BikeOnlyMiles', N'Date', N'date', N'date'),
    (N'S13', N'BikePart', N'StartDate', N'date', N'date'),
    (N'S13', N'BikePart', N'EndDate', N'date', N'date'),
    (N'S13', N'LiftingSession', N'Date', N'date', N'date'),
    (N'S13', N'Maintenance', N'Date', N'date', N'date'),
    (N'S13', N'MissedMiles', N'Date', N'date', N'date'),
    (N'S13', N'Shoe', N'AcquisitionDate', N'date', N'date'),
    (N'S13', N'Shoe', N'RetireDate', N'date', N'date'),
    (N'S13', N'Weight', N'Date', N'date', N'date'),
    (N'S12', N'Bike', N'Name', N'nvarchar(50)', N'nvarchar'),
    (N'S12', N'BikeType', N'Name', N'nvarchar(50)', N'nvarchar'),
    (N'S12', N'RouteType', N'Name', N'nvarchar(50)', N'nvarchar');

UPDATE c SET
    CurType = TYPE_NAME(sc.system_type_id)
              + CASE WHEN TYPE_NAME(sc.system_type_id) IN (N'varchar', N'char') THEN CONCAT(N'(', sc.max_length, N')')
                     WHEN TYPE_NAME(sc.system_type_id) IN (N'nvarchar', N'nchar') THEN CONCAT(N'(', sc.max_length / 2, N')')
                     ELSE N'' END,
    IsNullable = sc.is_nullable
FROM @Cols AS c
LEFT JOIN sys.columns AS sc ON sc.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(c.TableName)) AND sc.name = c.ColumnName;

UPDATE @Cols SET State = CASE WHEN CurType IS NULL THEN N'NOT FOUND' WHEN CurType = NewType THEN N'already done' ELSE N'to convert' END;

-- things that would block ALTER COLUMN and that this script does not recreate
UPDATE c SET State =
    CASE WHEN EXISTS (SELECT 1 FROM sys.foreign_key_columns AS f WHERE (f.parent_object_id = x.oid AND f.parent_column_id = x.cid)
                                                               OR (f.referenced_object_id = x.oid AND f.referenced_column_id = x.cid))
              THEN N'BLOCKED: in a foreign key'
         WHEN EXISTS (SELECT 1 FROM sys.index_columns AS ic JOIN sys.indexes AS i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
                      WHERE ic.object_id = x.oid AND ic.column_id = x.cid AND (i.is_primary_key = 1 OR i.is_unique_constraint = 1 OR i.type <> 2))
              THEN N'BLOCKED: in a primary key, unique constraint or non-rowstore index'
         WHEN EXISTS (SELECT 1 FROM sys.computed_columns AS cc WHERE cc.object_id = x.oid AND cc.definition LIKE N'%[[]' + c.ColumnName + N']%')
              THEN N'BLOCKED: used by a computed column'
         ELSE c.State END
FROM @Cols AS c
CROSS APPLY (SELECT OBJECT_ID(N'dbo.' + QUOTENAME(c.TableName)) AS oid, COLUMNPROPERTY(OBJECT_ID(N'dbo.' + QUOTENAME(c.TableName)), c.ColumnName, 'ColumnId') AS cid) AS x
WHERE c.State = N'to convert';

-- user-created statistics on a converted column are dropped and recreated with the same columns
DECLARE @seq int, @t sysname, @col sysname, @sql nvarchar(max), @n int, @keys nvarchar(max), @ixname sysname;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Seq, TableName, ColumnName FROM @Cols WHERE State = N'to convert' AND BaseType = N'date';
OPEN c; FETCH NEXT FROM c INTO @seq, @t, @col;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@t) + N' WHERE ' + QUOTENAME(@col) + N' IS NOT NULL AND CONVERT(time, '
             + QUOTENAME(@col) + N') <> CONVERT(time, ''00:00'');';
    EXEC sp_executesql @sql, N'@n int OUTPUT', @n = @n OUTPUT;
    UPDATE @Cols SET TimeRows = @n, Collisions = 0 WHERE Seq = @seq;

    -- unique indexes that contain the column: would two rows collide once the time is gone?
    DECLARE u CURSOR LOCAL FAST_FORWARD FOR
        SELECT i.name FROM sys.indexes AS i JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        WHERE i.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)) AND i.is_unique = 1 AND ic.column_id = COLUMNPROPERTY(i.object_id, @col, 'ColumnId');
    OPEN u; FETCH NEXT FROM u INTO @ixname;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @keys = STUFF((SELECT N', ' + CASE WHEN cl.name = @col THEN N'CONVERT(date, ' + QUOTENAME(cl.name) + N')' ELSE QUOTENAME(cl.name) END
                           FROM sys.index_columns AS ic JOIN sys.columns AS cl ON cl.object_id = ic.object_id AND cl.column_id = ic.column_id
                           WHERE ic.object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)) AND ic.index_id = INDEXPROPERTY(ic.object_id, @ixname, 'IndexID')
                             AND ic.is_included_column = 0
                           ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'');
        SET @sql = N'SELECT @n = COUNT(*) FROM (SELECT 1 AS x FROM dbo.' + QUOTENAME(@t) + N' GROUP BY ' + @keys + N' HAVING COUNT(*) > 1) AS d;';
        EXEC sp_executesql @sql, N'@n int OUTPUT', @n = @n OUTPUT;
        UPDATE @Cols SET Collisions = Collisions + @n, State = CASE WHEN @n > 0 THEN N'BLOCKED: values would collide in ' + @ixname ELSE State END
        WHERE Seq = @seq;
        FETCH NEXT FROM u INTO @ixname;
    END;
    CLOSE u; DEALLOCATE u;
    FETCH NEXT FROM c INTO @seq, @t, @col;
END;
CLOSE c; DEALLOCATE c;

SELECT Item, TableName, ColumnName, CurType, NewType, TimeRows AS RowsLosingTimeOfDay, Collisions, State FROM @Cols ORDER BY Seq;

IF EXISTS (SELECT 1 FROM @Cols WHERE State NOT IN (N'to convert', N'already done'))
BEGIN
    RAISERROR(N'Some columns cannot be converted (see State above). Nothing was changed.', 16, 1);
    RETURN;
END;

DECLARE @Count int = (SELECT COUNT(*) FROM @Cols WHERE State = N'to convert');
IF @Apply = 0
BEGIN
    PRINT CONCAT(N'Nothing changed. ', @Count, N' column(s) to convert; set @Apply = 1 to convert them.');
    RETURN;
END;

DECLARE @newtype nvarchar(30), @nullable bit, @oid int, @cid int;
DECLARE @Ix TABLE (Name sysname, CreateSql nvarchar(max));
DECLARE @Df TABLE (Name sysname, AddSql nvarchar(max));
DECLARE @Ck TABLE (Name sysname, AddSql nvarchar(max));
DECLARE @St TABLE (Name sysname, AddSql nvarchar(max));
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE a CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColumnName, NewType, IsNullable FROM @Cols WHERE State = N'to convert' ORDER BY Seq;
    OPEN a; FETCH NEXT FROM a INTO @t, @col, @newtype, @nullable;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @oid = OBJECT_ID(N'dbo.' + QUOTENAME(@t));
        SET @cid = COLUMNPROPERTY(@oid, @col, 'ColumnId');
        DELETE @Ix; DELETE @Df; DELETE @Ck; DELETE @St;

        INSERT @St (Name, AddSql)
        SELECT st.name, N'CREATE STATISTICS ' + QUOTENAME(st.name) + N' ON dbo.' + QUOTENAME(@t) + N' ('
               + STUFF((SELECT N', ' + QUOTENAME(cl.name) FROM sys.stats_columns AS sc2 JOIN sys.columns AS cl ON cl.object_id = sc2.object_id AND cl.column_id = sc2.column_id
                        WHERE sc2.object_id = st.object_id AND sc2.stats_id = st.stats_id ORDER BY sc2.stats_column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'')
               + N')' + CASE WHEN st.has_filter = 1 THEN N' WHERE ' + st.filter_definition ELSE N'' END + N';'
        FROM sys.stats AS st
        WHERE st.object_id = @oid AND st.user_created = 1
          AND EXISTS (SELECT 1 FROM sys.stats_columns AS sc WHERE sc.object_id = st.object_id AND sc.stats_id = st.stats_id AND sc.column_id = @cid);

        -- nonclustered indexes that contain the column, scripted exactly as they are
        INSERT @Ix (Name, CreateSql)
        SELECT i.name,
               N'CREATE ' + CASE WHEN i.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END + N'NONCLUSTERED INDEX ' + QUOTENAME(i.name)
               + N' ON dbo.' + QUOTENAME(@t) + N' ('
               + STUFF((SELECT N', ' + QUOTENAME(cl.name) + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END
                        FROM sys.index_columns AS ic JOIN sys.columns AS cl ON cl.object_id = ic.object_id AND cl.column_id = ic.column_id
                        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0 AND ic.key_ordinal > 0
                        ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') + N')'
               + ISNULL(N' INCLUDE (' + STUFF((SELECT N', ' + QUOTENAME(cl.name)
                        FROM sys.index_columns AS ic JOIN sys.columns AS cl ON cl.object_id = ic.object_id AND cl.column_id = ic.column_id
                        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                        ORDER BY ic.index_column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'') + N')', N'')
               + CASE WHEN i.has_filter = 1 THEN N' WHERE ' + i.filter_definition ELSE N'' END
               + ISNULL(N' WITH (' + STUFF(
                     CASE WHEN i.fill_factor > 0 THEN N', FILLFACTOR = ' + CONVERT(nvarchar(3), i.fill_factor) ELSE N'' END
                   + CASE WHEN i.is_padded = 1 THEN N', PAD_INDEX = ON' ELSE N'' END
                   + CASE WHEN i.ignore_dup_key = 1 THEN N', IGNORE_DUP_KEY = ON' ELSE N'' END
                   + CASE WHEN i.allow_row_locks = 0 THEN N', ALLOW_ROW_LOCKS = OFF' ELSE N'' END
                   + CASE WHEN i.allow_page_locks = 0 THEN N', ALLOW_PAGE_LOCKS = OFF' ELSE N'' END, 1, 2, N'') + N')', N'')
               + N';'
        FROM sys.indexes AS i
        WHERE i.object_id = @oid AND i.type = 2 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
          AND EXISTS (SELECT 1 FROM sys.index_columns AS ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.column_id = @cid);

        INSERT @Df (Name, AddSql)
        SELECT dc.name, N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ADD CONSTRAINT ' + QUOTENAME(dc.name) + N' DEFAULT ' + dc.definition
                        + N' FOR ' + QUOTENAME(@col) + N';'
        FROM sys.default_constraints AS dc WHERE dc.parent_object_id = @oid AND dc.parent_column_id = @cid;

        INSERT @Ck (Name, AddSql)
        SELECT cc.name, N'ALTER TABLE dbo.' + QUOTENAME(@t) + CASE WHEN cc.is_not_trusted = 1 THEN N' WITH NOCHECK' ELSE N' WITH CHECK' END
                        + N' ADD CONSTRAINT ' + QUOTENAME(cc.name) + N' CHECK ' + cc.definition + N';'
                        + CASE WHEN cc.is_disabled = 1 THEN N' ALTER TABLE dbo.' + QUOTENAME(@t) + N' NOCHECK CONSTRAINT ' + QUOTENAME(cc.name) + N';' ELSE N'' END
        FROM sys.check_constraints AS cc
        WHERE cc.parent_object_id = @oid AND (cc.parent_column_id = @cid OR cc.definition LIKE N'%[[]' + @col + N']%');

        DECLARE d CURSOR LOCAL FAST_FORWARD FOR
            SELECT N'DROP INDEX ' + QUOTENAME(Name) + N' ON dbo.' + QUOTENAME(@t) + N';' FROM @Ix
            UNION ALL SELECT N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' DROP CONSTRAINT ' + QUOTENAME(Name) + N';' FROM @Df
            UNION ALL SELECT N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' DROP CONSTRAINT ' + QUOTENAME(Name) + N';' FROM @Ck
            UNION ALL SELECT N'DROP STATISTICS dbo.' + QUOTENAME(@t) + N'.' + QUOTENAME(Name) + N';' FROM @St;
        OPEN d; FETCH NEXT FROM d INTO @sql;
        WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_executesql @sql; FETCH NEXT FROM d INTO @sql; END;
        CLOSE d; DEALLOCATE d;

        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' ALTER COLUMN ' + QUOTENAME(@col) + N' ' + @newtype
                 + CASE WHEN @nullable = 1 THEN N' NULL;' ELSE N' NOT NULL;' END;
        PRINT @sql;
        EXEC sp_executesql @sql;

        DECLARE r CURSOR LOCAL FAST_FORWARD FOR
            SELECT AddSql FROM @Df UNION ALL SELECT AddSql FROM @Ck UNION ALL SELECT CreateSql FROM @Ix UNION ALL SELECT AddSql FROM @St;
        OPEN r; FETCH NEXT FROM r INTO @sql;
        WHILE @@FETCH_STATUS = 0 BEGIN PRINT N'   ' + @sql; EXEC sp_executesql @sql; FETCH NEXT FROM r INTO @sql; END;
        CLOSE r; DEALLOCATE r;

        FETCH NEXT FROM a INTO @t, @col, @newtype, @nullable;
    END;
    CLOSE a; DEALLOCATE a;

    DECLARE v CURSOR LOCAL FAST_FORWARD FOR SELECT QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) FROM sys.views WHERE schema_id = SCHEMA_ID(N'dbo');
    OPEN v; FETCH NEXT FROM v INTO @sql;
    WHILE @@FETCH_STATUS = 0 BEGIN EXEC sp_refreshview @sql; FETCH NEXT FROM v INTO @sql; END;
    CLOSE v; DEALLOCATE v;

    COMMIT;
    PRINT CONCAT(N'Converted ', @Count, N' column(s); views refreshed.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO

SET NOEXEC OFF;
GO
