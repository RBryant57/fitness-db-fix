-- dbo.RecreationalRide, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- Removed: RideTimeHours, RideTimeMinutes, RideTimeSeconds, BikeTimeHours, BikeTimeMinutes, BikeTimeSeconds.
-- Removed with them: CK_BikeRecTimeHours, CK_BikeRecTimeMinutes, CK_BikeRecTimeSeconds, CK_RideRecTimeHours, CK_RideRecTimeMinutes, CK_RideRecTimeSeconds, DF_RecreationalRide_BikeTimeHours, DF_RecreationalRide_BikeTimeMinutes, DF_RecreationalRide_BikeTimeSeconds, DF_RecreationalRide_RideTimeHours, DF_RecreationalRide_RideTimeMinutes, DF_RecreationalRide_RideTimeSeconds.
-- Computed (not stored), text in the form hh:mm:ss: Duration (StartTime to EndTime), BikeDuration (StartTime to BikeEndTime), RestDuration (BikeEndTime to EndTime; shown with a leading minus if BikeEndTime is after EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- Changed: Notes is nvarchar(4000) (it is still text in production; every other Notes column is already nvarchar).
-- In the dacpac these foreign keys are not trusted (created WITH NOCHECK): FK_RecreationalRide_Bike, FK_RecreationalRide_GpxJson, FK_RecreationalRide_Route.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.RecreationalRide
(
    Id               int            IDENTITY(1, 1) NOT NULL,
    [Date]           datetime       NOT NULL,
    StartOdometer    int            NOT NULL,
    EndOdometer      int            NOT NULL,
    Distance         decimal(9, 4)  NULL,
    StartTime        datetime       NOT NULL,
    EndTime          datetime       NOT NULL,
    Duration         AS CONCAT(CASE WHEN DATEDIFF(second, StartTime, EndTime) / 3600 < 10 THEN '0' ELSE '' END,
                               DATEDIFF(second, StartTime, EndTime) / 3600, ':',
                               RIGHT(CONCAT('0', DATEDIFF(second, StartTime, EndTime) % 3600 / 60), 2), ':',
                               RIGHT(CONCAT('0', DATEDIFF(second, StartTime, EndTime) % 60), 2)),
    BikeEndTime      datetime       NOT NULL,
    BikeDuration     AS CONCAT(CASE WHEN DATEDIFF(second, StartTime, BikeEndTime) / 3600 < 10 THEN '0' ELSE '' END,
                               DATEDIFF(second, StartTime, BikeEndTime) / 3600, ':',
                               RIGHT(CONCAT('0', DATEDIFF(second, StartTime, BikeEndTime) % 3600 / 60), 2), ':',
                               RIGHT(CONCAT('0', DATEDIFF(second, StartTime, BikeEndTime) % 60), 2)),
    RestDuration     AS CONCAT(CASE WHEN DATEDIFF(second, BikeEndTime, EndTime) < 0 THEN '-' ELSE '' END,
                               CASE WHEN ABS(DATEDIFF(second, BikeEndTime, EndTime)) / 3600 < 10 THEN '0' ELSE '' END, ABS(DATEDIFF(second, BikeEndTime, EndTime)) / 3600, ':',
                               RIGHT(CONCAT('0', ABS(DATEDIFF(second, BikeEndTime, EndTime)) % 3600 / 60), 2), ':',
                               RIGHT(CONCAT('0', ABS(DATEDIFF(second, BikeEndTime, EndTime)) % 60), 2)),
    AverageHR        int            NOT NULL,
    MaxHR            int            NOT NULL,
    AverageCadence   int            NOT NULL,
    ElevationGain    int            NOT NULL,
    MaxSpeed         decimal(9, 4)  NOT NULL,
    Wind             nvarchar(255)  NOT NULL,
    Temperature      int            NOT NULL,
    Precipitation    bit            NOT NULL,
    BikeId           int            NOT NULL,
    RouteId          int            NOT NULL,
    GpxJsonId        int            NULL,
    Notes            nvarchar(4000) NULL,

    CONSTRAINT PK_RecreationalRide PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_RecreationalRide_Bike FOREIGN KEY (BikeId) REFERENCES dbo.Bike (Id),
    CONSTRAINT FK_RecreationalRide_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_RecreationalRide_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT CK_AverageRecCadence CHECK (AverageCadence>(0) AND AverageCadence<(200)),
    CONSTRAINT CK_AverageRecHR CHECK (AverageHR>(0) AND AverageHR<(220)),
    CONSTRAINT CK_EndRecOdometer CHECK (EndOdometer>(0)),
    CONSTRAINT CK_MaxRecHR CHECK (MaxHR>(0) AND MaxHR<(220)),
    CONSTRAINT CK_RideRecMiles CHECK (EndOdometer>StartOdometer),
    CONSTRAINT CK_StartRecOdometer CHECK (StartOdometer>(0))
);
GO

-- Tables that reference dbo.RecreationalRide:
--   dbo.RecreationalRideGPX -> FK_RecreationalRideGPX_RecreationalRide
