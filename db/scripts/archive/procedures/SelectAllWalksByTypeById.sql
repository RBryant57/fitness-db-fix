-- Fixed version of dbo.SelectAllWalksByTypeById (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllWalksByTypeById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllWalksByTypeById
-- Changes:
--   * Duplicate column names removed; prefixed names (ShoeName, RouteName, ShoeManufacturerName, ...).
--   * Training walks now include MaxSpeed, NumberOfAttempts, NumberOfSuccesses and GpxJsonId; recreational walks GpxJsonId.
--   * text/ntext cast; WindDirection trimmed; an unknown @WalkType raises an error.
--   Walk types (unchanged): 1 training, 2 recreational.
CREATE OR ALTER PROCEDURE dbo.SelectAllWalksByTypeById
    @WalkType int,
    @Id       int
AS
BEGIN
    SET NOCOUNT ON;

    IF @WalkType IS NULL OR @WalkType NOT IN (1, 2)
        THROW 50009, N'Unknown walk type (expected 1 or 2).', 1;

    IF @WalkType = 1
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.WalkTimeHours, r.WalkTimeMinutes, r.WalkTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain, r.MaxSpeed,
               r.WindSpeed, RTRIM(r.WindDirection) AS WindDirection, r.Temperature, r.Precipitation,
               r.NumberOfAttempts, r.NumberOfSuccesses, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')    AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes,
               r.RouteId,
               ro.[Name]                                      AS RouteName,
               ro.City                                        AS RouteCity,
               ro.[State]                                     AS RouteState,
               ro.TypeId                                      AS RouteTypeId,
               rt.EnumId                                      AS RouteTypeEnumId,
               rt.[Name]                                      AS RouteTypeName,
               ro.Rating                                      AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '')   AS RouteNotes
        FROM dbo.TrainingWalk AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.WalkTimeHours, r.WalkTimeMinutes, r.WalkTimeSeconds,
               r.PathEndTime, r.PathTimeHours, r.PathTimeMinutes, r.PathTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain, r.MaxSpeed,
               r.Wind, r.Temperature, r.Precipitation, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')    AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes,
               r.RouteId,
               ro.[Name]                                      AS RouteName,
               ro.City                                        AS RouteCity,
               ro.[State]                                     AS RouteState,
               ro.TypeId                                      AS RouteTypeId,
               rt.EnumId                                      AS RouteTypeEnumId,
               rt.[Name]                                      AS RouteTypeName,
               ro.Rating                                      AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '')   AS RouteNotes
        FROM dbo.RecreationalWalk AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
END;
GO
