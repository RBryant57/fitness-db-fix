-- Fixed version of dbo.SelectAllRidesByTypeByDate (2026-10-14). The pre-fix original is archive/procedures-original/SelectAllRidesByTypeByDate.sql.
-- Deployed by archive/scripts/00b_apply_procedure_fixes.sql; kept for reference after archiving.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.SelectAllRidesByTypeByDate
-- Changes:
--   * Result sets had duplicate column names (BikeId x2, RouteTypeId x2, ManufacturerId x2, Name used for several
--     things), which ADO.NET renames to Name1, Name2... Every column now has one unique, prefixed name
--     (BikeName, RouteName, RouteCity, BikeManufacturerName, ...).
--   * Training rides now include the columns added since the proc was written: Distance, MaxSpeed,
--     NumberOfAttempts, NumberOfSuccesses, GpxJsonId. Recreational rides include Distance and GpxJsonId.
--   * text/ntext columns cast to (n)varchar(max); WindDirection trimmed; ORDER BY Date, StartTime.
--   * @StartDate and @EndDate are independently optional (end inclusive); an unknown @RideType raises an error.
--   Ride types (unchanged): 1 training, 2 recreational.
CREATE OR ALTER PROCEDURE dbo.SelectAllRidesByTypeByDate
    @RideType  int,
    @StartDate date = NULL,
    @EndDate   date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @RideType IS NULL OR @RideType NOT IN (1, 2)
        THROW 50009, N'Unknown ride type (expected 1 or 2).', 1;

    DECLARE @EndExclusive date = DATEADD(day, 1, @EndDate);

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
        WHERE (@StartDate IS NULL OR r.[Date] >= @StartDate)
          AND (@EndDate   IS NULL OR r.[Date] <  @EndExclusive)
        ORDER BY r.[Date], r.StartTime
        OPTION (RECOMPILE);
    ELSE
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
        WHERE (@StartDate IS NULL OR r.[Date] >= @StartDate)
          AND (@EndDate   IS NULL OR r.[Date] <  @EndExclusive)
        ORDER BY r.[Date], r.StartTime
        OPTION (RECOMPILE);
END;
GO
