-- Fixed version of dbo.GetPartById (2026-10-14). The pre-fix original is archive/procedures-original/GetPartById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetPartById
-- Changes:
--   * BUG: LEFT JOIN to BikePart returned one row per installation, so a part fitted more than once came back as
--     several rows. Now returns exactly one row with the most recent installation (StartDate, EndDate, BikeId).
--   * text Notes cast to varchar(max); schema-qualified.
CREATE OR ALTER PROCEDURE dbo.GetPartById
    @PartId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id                                         AS PartId,
           p.[Name]                                     AS PartName,
           COALESCE(CAST(p.Notes AS varchar(max)), '')  AS PartNotes,
           m.Id                                         AS ManufacturerId,
           m.[Name]                                     AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')  AS ManufacturerNotes,
           pt.Id                                        AS PartTypeId,
           pt.[Name]                                    AS PartTypeName,
           lastFit.BikeId,
           lastFit.StartDate,
           lastFit.EndDate
    FROM dbo.Part AS p
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    OUTER APPLY (
        SELECT TOP (1) bp.BikeId, bp.StartDate, bp.EndDate
        FROM dbo.BikePart AS bp
        WHERE bp.PartId = p.Id
        ORDER BY bp.StartDate DESC, bp.Id DESC
    ) AS lastFit
    WHERE p.Id = @PartId;
END;
GO
