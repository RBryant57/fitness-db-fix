-- Fixed version of dbo.SelectAllParts (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllParts.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllParts
-- Changes:
--   * text Notes cast to varchar(max); Part.Id added as tiebreaker in ORDER BY; schema-qualified.
CREATE OR ALTER PROCEDURE dbo.SelectAllParts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id,
           p.[Name],
           COALESCE(CAST(p.Notes AS varchar(max)), '') AS Notes,
           m.Id                                        AS ManufacturerId,
           m.[Name]                                    AS ManufacturerName,
           pt.Id                                       AS PartTypeId,
           pt.[Name]                                   AS PartTypeName
    FROM dbo.Part AS p
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = p.ManufacturerId
    INNER JOIN dbo.PartType     AS pt ON pt.Id = p.PartTypeId
    ORDER BY m.[Name], pt.[Name], p.Id;
END;
GO
