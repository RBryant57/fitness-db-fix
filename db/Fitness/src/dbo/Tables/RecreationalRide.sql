-- dbo.RecreationalRide after the S5 rebuild: computed durations (time(0)) follow their end times.
-- Removed: RideTimeHours, RideTimeMinutes, RideTimeSeconds, BikeTimeHours, BikeTimeMinutes, BikeTimeSeconds.
-- Removed with them: CK_BikeRecTimeHours, CK_BikeRecTimeMinutes, CK_BikeRecTimeSeconds, CK_RideRecTimeHours, CK_RideRecTimeMinutes, CK_RideRecTimeSeconds, DF_RecreationalRide_BikeTimeHours, DF_RecreationalRide_BikeTimeMinutes, DF_RecreationalRide_BikeTimeSeconds, DF_RecreationalRide_RideTimeHours, DF_RecreationalRide_RideTimeMinutes, DF_RecreationalRide_RideTimeSeconds.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime), BikeDuration (StartTime to BikeEndTime), RestDuration (BikeEndTime to EndTime).
-- Check CK_RecreationalRide_RestNotNegative: BikeEndTime may not be after EndTime (rest time cannot be negative).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- Changed: Notes is nvarchar(4000) (the agreed type for every Notes column).
CREATE TABLE dbo.RecreationalRide
(
    Id               int            IDENTITY(1, 1) NOT NULL,
    [Date]           datetime       NOT NULL,
    StartOdometer    int            NOT NULL,
    EndOdometer      int            NOT NULL,
    Distance         decimal(9, 4)  NULL,
    StartTime        datetime       NOT NULL,
    EndTime          datetime       NOT NULL,
    Duration         AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    BikeEndTime      datetime       NOT NULL,
    BikeDuration     AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, BikeEndTime), 0), 0),
    RestDuration     AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, BikeEndTime, EndTime), 0), 0),
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
    CONSTRAINT CK_StartRecOdometer CHECK (StartOdometer>(0)),
    CONSTRAINT CK_RecreationalRide_RestNotNegative CHECK (BikeEndTime <= EndTime)
);
GO
