-- Fixed version of dbo.GetCurrentBikePartsById (2026-10-14). The pre-fix original is archive/procedures-original/GetCurrentBikePartsById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetCurrentBikePartsById
-- Changes:
--   * Two near-identical branches merged into one query; @BikeId = 0 still means "all bikes", and NULL now means the
--     same (previously NULL returned no rows).
--   * The single-bike branch had no ORDER BY; both now order by BikeId, PartTypeName.
--   * text Notes cast to varchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetCurrentBikePartsById
    @BikeId int = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id                                          AS PartId,
           p.[Name]                                      AS PartName,
           COALESCE(CAST(p.Notes AS varchar(max)), '')   AS PartNotes,
           m.Id                                          AS ManufacturerId,
           m.[Name]                                      AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')   AS ManufacturerNotes,
           pt.Id                                         AS PartTypeId,
           pt.[Name]                                     AS PartTypeName,
           COALESCE(CAST(pt.Notes AS varchar(max)), '')  AS PartTypeNotes,
           bp.BikeId
    FROM dbo.BikePart AS bp
    INNER JOIN dbo.Part         AS p  ON p.Id  = bp.PartId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    WHERE bp.EndDate IS NULL
      AND (@BikeId IS NULL OR @BikeId = 0 OR bp.BikeId = @BikeId)
    ORDER BY bp.BikeId, pt.[Name]
    OPTION (RECOMPILE);
END;
GO
