-- Fixed version of dbo.GetMaintenanceSubset (2026-10-14). The pre-fix original is archive/procedures-original/GetMaintenanceSubset.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetMaintenanceSubset
-- Changes:
--   * BUG (broken today): same `[Bike] = @BikeId` name-vs-id comparison as GetMaintenanceByBikeId. Now filters on
--     Maintenance.BikeId against the base tables.
--   * ROW_NUMBER CTE + SELECT * replaced by OFFSET/FETCH with explicit columns and a deterministic order.
--   * Column names without spaces ([Operation Date] -> OperationDate, [Part Type] -> PartType, [Action Taken] ->
--     ActionTaken); Id added; the helper RowNumber column is no longer returned.
--   * @StartIndex is still 1-based; invalid or NULL paging arguments raise an error.
CREATE OR ALTER PROCEDURE dbo.GetMaintenanceSubset
    @BikeId          int,
    @StartIndex      int,
    @NumberOfRecords int
AS
BEGIN
    SET NOCOUNT ON;

    IF COALESCE(@StartIndex, 0) < 1 OR COALESCE(@NumberOfRecords, 0) < 1
        THROW 50005, N'StartIndex and NumberOfRecords must be 1 or greater.', 1;

    SELECT mt.Id,
           mt.[Date]                                   AS OperationDate,
           b.[Name]                                    AS Bike,
           mf.[Name]                                   AS Manufacturer,
           p.[Name]                                    AS Part,
           pt.[Name]                                   AS PartType,
           mt.ActionTaken,
           mt.Odometer,
           COALESCE(CAST(mt.Notes AS varchar(max)), '') AS Notes
    FROM dbo.Maintenance AS mt
    INNER JOIN dbo.Bike         AS b  ON b.Id  = mt.BikeId
    INNER JOIN dbo.Part         AS p  ON p.Id  = mt.PartId
    INNER JOIN dbo.Manufacturer AS mf ON mf.Id = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    WHERE mt.BikeId = @BikeId
    ORDER BY mt.Odometer, mt.Id
    OFFSET @StartIndex - 1 ROWS FETCH NEXT @NumberOfRecords ROWS ONLY;
END;
GO
