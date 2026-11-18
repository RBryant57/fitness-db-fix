-- dbo.StationaryRide after the S5 rebuild: computed durations (time(0)) follow their end times.
-- Removed: RideTimeHours, RideTimeMinutes, RideTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
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
