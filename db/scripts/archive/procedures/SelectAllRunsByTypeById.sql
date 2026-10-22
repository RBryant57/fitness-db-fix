-- Fixed version of dbo.SelectAllRunsByTypeById (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllRunsByTypeById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllRunsByTypeById
-- Changes:
--   * Duplicate column names removed (ShoeId x2, RouteId x2, RouteTypeId x2, ManufacturerId x2); prefixed names
--     (ShoeName, RouteName, ShoeManufacturerName, ...).
--   * Training runs now include MaxSpeed, NumberOfAttempts, NumberOfSuccesses and GpxJsonId; recreational runs GpxJsonId.
--   * text/ntext cast; WindDirection trimmed; an unknown @RunType raises an error.
--   Run types (unchanged): 1 training, 2 recreational, 3 treadmill.
CREATE OR ALTER PROCEDURE dbo.SelectAllRunsByTypeById
    @RunType int,
    @Id      int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunType IS NULL OR @RunType NOT IN (1, 2, 3)
        THROW 50009, N'Unknown run type (expected 1, 2 or 3).', 1;

    IF @RunType = 1
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.RunTimeHours, r.RunTimeMinutes, r.RunTimeSeconds,
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
        FROM dbo.TrainingRun AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE IF @RunType = 2
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.RunTimeHours, r.RunTimeMinutes, r.RunTimeSeconds,
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
        FROM dbo.RecreationalRun AS r
        INNER JOIN dbo.Shoe         AS s  ON s.Id  = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = s.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE
        SELECT r.Id, r.[Date], r.Distance, r.StartTime, r.EndTime,
               r.RunTimeHours, r.RunTimeMinutes, r.RunTimeSeconds,
               r.AverageHR, r.MaxHR, r.ElevationGain,
               COALESCE(CAST(r.Notes AS nvarchar(max)), N'')  AS Notes,
               r.ShoeId,
               s.[Name]                                       AS ShoeName,
               s.ManufacturerId                               AS ShoeManufacturerId,
               m.[Name]                                       AS ShoeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')    AS ShoeManufacturerNotes,
               s.AcquisitionDate                              AS ShoeAcquisitionDate,
               COALESCE(CAST(s.Notes AS nvarchar(max)), N'')  AS ShoeNotes
        FROM dbo.TreadmillRun AS r
        INNER JOIN dbo.Shoe         AS s ON s.Id = r.ShoeId
        INNER JOIN dbo.Manufacturer AS m ON m.Id = s.ManufacturerId
        WHERE r.Id = @Id;
END;
GO
