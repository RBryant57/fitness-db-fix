-- dbo.StationaryRide, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- Removed: RideTimeHours, RideTimeMinutes, RideTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- In the dacpac these foreign keys are not trusted (created WITH NOCHECK): FK_StationaryRide_Bike.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.StationaryRide
(
    Id               int            IDENTITY(1, 1) NOT NULL,
    [Date]           datetime       NOT NULL,
    StartOdometer    int            NOT NULL,
    EndOdometer      int            NOT NULL,
    Distance         decimal(9, 4)  NULL,
    StartTime        datetime       NOT NULL,
    EndTime          datetime       NOT NULL,
    Duration         AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    AverageHR        int            NOT NULL,
    MaxHR            int            NOT NULL,
    AverageCadence   int            NOT NULL,
    BikeId           int            NULL,
    Notes            nvarchar(4000) NULL,

    CONSTRAINT PK_StationaryRide PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_StationaryRide_Bike FOREIGN KEY (BikeId) REFERENCES dbo.Bike (Id)
);
GO
