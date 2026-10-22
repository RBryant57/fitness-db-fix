-- Fixed version of dbo.SelectAllRidesByTypeById (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllRidesByTypeById.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllRidesByTypeById
-- Changes:
--   * BUG: type 3 (stationary) used `LEFT JOIN Bike ... INNER JOIN BikeType ... INNER JOIN Manufacturer`; the inner
--     joins cancelled the outer join, so a trainer ride with no bike (BikeId NULL) returned no row. All bike joins are
--     LEFT JOINs for type 3 now.
--   * Duplicate column names removed (same naming as SelectAllRidesByTypeByDate); Distance / GpxJsonId / attempt
--     columns included; text/ntext cast; WindDirection trimmed.
--   * An unknown @RideType raises an error.
--   Ride types (unchanged): 1 training, 2 recreational, 3 stationary.
CREATE OR ALTER PROCEDURE dbo.SelectAllRidesByTypeById
    @RideType int,
    @Id       int
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT IN (1, 2, 3)
        THROW 50009, N'Unknown ride type (expected 1, 2 or 3).', 1;

    IF @RideType = 1
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence, r.ElevationGain, r.MaxSpeed,
               r.WindSpeed, RTRIM(r.WindDirection) AS WindDirection, r.Temperature, r.Precipitation,
               r.NumberOfAttempts, r.NumberOfSuccesses, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')  AS Notes,
               r.BikeId,
               b.[Name]                                     AS BikeName,
               b.ManufacturerId                             AS BikeManufacturerId,
               m.[Name]                                     AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')  AS BikeManufacturerNotes,
               b.TypeId                                     AS BikeTypeId,
               bt.EnumId                                    AS BikeTypeEnumId,
               bt.[Name]                                    AS BikeTypeName,
               b.AcquisitionDate                            AS BikeAcquisitionDate,
               b.BaseMiles                                  AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')  AS BikeNotes,
               r.RouteId,
               ro.[Name]                                    AS RouteName,
               ro.City                                      AS RouteCity,
               ro.[State]                                   AS RouteState,
               ro.TypeId                                    AS RouteTypeId,
               rt.EnumId                                    AS RouteTypeEnumId,
               rt.[Name]                                    AS RouteTypeName,
               ro.Rating                                    AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '') AS RouteNotes
        FROM dbo.TrainingRide AS r
        INNER JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE IF @RideType = 2
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.BikeEndTime, r.BikeTimeHours, r.BikeTimeMinutes, r.BikeTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence, r.ElevationGain, r.MaxSpeed,
               r.Wind, r.Temperature, r.Precipitation, r.GpxJsonId,
               COALESCE(CAST(r.Notes AS varchar(max)), '')  AS Notes,
               r.BikeId,
               b.[Name]                                     AS BikeName,
               b.ManufacturerId                             AS BikeManufacturerId,
               m.[Name]                                     AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')  AS BikeManufacturerNotes,
               b.TypeId                                     AS BikeTypeId,
               bt.EnumId                                    AS BikeTypeEnumId,
               bt.[Name]                                    AS BikeTypeName,
               b.AcquisitionDate                            AS BikeAcquisitionDate,
               b.BaseMiles                                  AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')  AS BikeNotes,
               r.RouteId,
               ro.[Name]                                    AS RouteName,
               ro.City                                      AS RouteCity,
               ro.[State]                                   AS RouteState,
               ro.TypeId                                    AS RouteTypeId,
               rt.EnumId                                    AS RouteTypeEnumId,
               rt.[Name]                                    AS RouteTypeName,
               ro.Rating                                    AS RouteRating,
               COALESCE(CAST(ro.Notes AS varchar(max)), '') AS RouteNotes
        FROM dbo.RecreationalRide AS r
        INNER JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        INNER JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        INNER JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        INNER JOIN dbo.[Route]      AS ro ON ro.Id = r.RouteId
        INNER JOIN dbo.RouteType    AS rt ON rt.Id = ro.TypeId
        WHERE r.Id = @Id;
    ELSE
        SELECT r.Id, r.[Date], r.StartOdometer, r.EndOdometer, r.Distance, r.StartTime, r.EndTime,
               r.RideTimeHours, r.RideTimeMinutes, r.RideTimeSeconds,
               r.AverageHR, r.MaxHR, r.AverageCadence,
               COALESCE(CAST(r.Notes AS nvarchar(max)), N'') AS Notes,
               r.BikeId,
               b.[Name]                                      AS BikeName,
               b.ManufacturerId                              AS BikeManufacturerId,
               m.[Name]                                      AS BikeManufacturerName,
               COALESCE(CAST(m.Notes AS varchar(max)), '')   AS BikeManufacturerNotes,
               b.TypeId                                      AS BikeTypeId,
               bt.EnumId                                     AS BikeTypeEnumId,
               bt.[Name]                                     AS BikeTypeName,
               b.AcquisitionDate                             AS BikeAcquisitionDate,
               b.BaseMiles                                   AS BikeBaseMiles,
               COALESCE(CAST(b.Notes AS varchar(max)), '')   AS BikeNotes
        FROM dbo.StationaryRide AS r
        LEFT JOIN dbo.Bike         AS b  ON b.Id  = r.BikeId
        LEFT JOIN dbo.BikeType     AS bt ON bt.Id = b.TypeId
        LEFT JOIN dbo.Manufacturer AS m  ON m.Id  = b.ManufacturerId
        WHERE r.Id = @Id;
END;
GO
