-- dbo.TrainingRide, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- Removed: RideTimeHours, RideTimeMinutes, RideTimeSeconds.
-- Removed with them: CK_RideTimeHours, CK_RideTimeMinutes, CK_RideTimeSeconds, DF_TrainingRide_RideTimeHours, DF_TrainingRide_RideTimeMinutes, DF_TrainingRide_RideTimeSeconds.
-- Computed (not stored), text in the form hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- In the dacpac these foreign keys are not trusted (created WITH NOCHECK): FK_TrainingRide_Bike, FK_TrainingRide_GpxJson, FK_TrainingRide_Route.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.TrainingRide
(
    Id                 int            IDENTITY(1, 1) NOT NULL,
    [Date]             datetime       NOT NULL,
    StartOdometer      int            NOT NULL,
    EndOdometer        int            NOT NULL,
    Distance           decimal(9, 4)  NULL,
    StartTime          datetime       NOT NULL,
    EndTime            datetime       NOT NULL,
    Duration           AS CONCAT(CASE WHEN DATEDIFF(second, StartTime, EndTime) / 3600 < 10 THEN '0' ELSE '' END,
                                 DATEDIFF(second, StartTime, EndTime) / 3600, ':',
                                 RIGHT(CONCAT('0', DATEDIFF(second, StartTime, EndTime) % 3600 / 60), 2), ':',
                                 RIGHT(CONCAT('0', DATEDIFF(second, StartTime, EndTime) % 60), 2)),
    AverageHR          int            NOT NULL,
    MaxHR              int            NOT NULL,
    AverageCadence     int            NOT NULL,
    ElevationGain      int            NOT NULL,
    MaxSpeed           decimal(9, 4)  NOT NULL CONSTRAINT DF_TrainingRide_MaxSpeed DEFAULT ((20)),
    WindSpeed          int            NOT NULL,
    WindDirection      nvarchar(3)    NOT NULL,
    Temperature        int            NOT NULL,
    Precipitation      bit            NOT NULL,
    BikeId             int            NOT NULL,
    RouteId            int            NOT NULL,
    NumberOfAttempts   int            NOT NULL CONSTRAINT DF_TrainingRide_NumberOfAttempts DEFAULT ((0)),
    NumberOfSuccesses  int            NOT NULL CONSTRAINT DF_TrainingRide_NumberOfSuccesses DEFAULT ((0)),
    GpxJsonId          int            NULL,
    Notes              nvarchar(max)  NULL,

    CONSTRAINT PK_TrainingRide PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TrainingRide_Bike FOREIGN KEY (BikeId) REFERENCES dbo.Bike (Id),
    CONSTRAINT FK_TrainingRide_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_TrainingRide_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT CK_AverageCadence CHECK (AverageCadence>(0) AND AverageCadence<(200)),
    CONSTRAINT CK_AverageHR CHECK (AverageHR>(0) AND AverageHR<(220)),
    CONSTRAINT CK_EndOdometer CHECK (EndOdometer>(0)),
    CONSTRAINT CK_MaxHR CHECK (MaxHR>(0) AND MaxHR<(220)),
    CONSTRAINT CK_RideMiles CHECK (EndOdometer>StartOdometer),
    CONSTRAINT CK_StartOdometer CHECK (StartOdometer>=(0)),
    CONSTRAINT CK_WindSpeed CHECK (WindSpeed>=(0))
);
GO

-- Tables that reference dbo.TrainingRide:
--   dbo.HRZoneTime -> FK_HRZoneTime_TrainingRides
--   dbo.TrainingRideGPX -> FK_TrainingRideGPX_TrainingRide
