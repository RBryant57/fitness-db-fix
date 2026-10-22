-- Fixed version of dbo.GetBikeById (2026-10-14). The pre-fix original is archive/procedures-original/GetBikeById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.GetBikeById
-- Changes:
--   * The Notes column came back unnamed (`COALESCE(Bike.Notes, '')` with no alias). Now aliased Notes.
--   * text columns cast to varchar(max) so callers get a modern type; AcquisitionDate added.
--   * Schema-qualified with table aliases.
CREATE OR ALTER PROCEDURE dbo.GetBikeById
    @BikeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT b.Id,
           b.[Name]                                        AS BikeName,
           bt.[Name]                                       AS TypeName,
           b.TypeId,
           b.BaseMiles,
           b.AcquisitionDate,
           COALESCE(CAST(b.Notes AS varchar(max)), '')     AS Notes,
           m.Id                                            AS ManufacturerId,
           m.[Name]                                        AS ManufacturerName,
           COALESCE(CAST(m.Notes AS varchar(max)), '')     AS ManufacturerNotes
    FROM dbo.Bike AS b
    INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
    INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
    WHERE b.Id = @BikeId;
END;
GO
