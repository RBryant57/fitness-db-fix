-- Fixed version of dbo.SelectAllPartsSubset (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllPartsSubset.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllPartsSubset
-- Changes:
--   * ROW_NUMBER CTE + SELECT * replaced by OFFSET/FETCH with an explicit column list.
--   * Paging is now deterministic (Part.Id tiebreaker; the original ORDER BY could reorder ties between pages).
--   * @StartIndex is still 1-based; values below 1, a non-positive page size or NULLs raise an error.
--   * The helper RowNumber column is no longer returned.
CREATE OR ALTER PROCEDURE dbo.SelectAllPartsSubset
    @StartIndex      int,
    @NumberOfRecords int
AS
BEGIN
    SET NOCOUNT ON;

    IF COALESCE(@StartIndex, 0) < 1 OR COALESCE(@NumberOfRecords, 0) < 1
        THROW 50005, N'StartIndex and NumberOfRecords must be 1 or greater.', 1;

    SELECT p.Id,
           m.[Name]                                    AS ManufacturerName,
           p.[Name],
           pt.[Name]                                   AS PartTypeName,
           COALESCE(CAST(p.Notes AS varchar(max)), '') AS Notes,
           pt.Id                                       AS PartTypeId,
           m.Id                                        AS ManufacturerId
    FROM dbo.Part AS p
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    ORDER BY m.[Name], pt.[Name], p.Id
    OFFSET @StartIndex - 1 ROWS FETCH NEXT @NumberOfRecords ROWS ONLY;
END;
GO
