-- dbo.RecreationalRun after the S5 rebuild: computed durations (time(0)) follow their end times.
-- Removed: RunTimeHours, RunTimeMinutes, RunTimeSeconds, PathTimeHours, PathTimeMinutes, PathTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime), PathDuration (StartTime to PathEndTime), RestDuration (PathEndTime to EndTime).
-- Check CK_RecreationalRun_RestNotNegative: PathEndTime may not be after EndTime (rest time cannot be negative).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
CREATE TABLE dbo.RecreationalRun
(
    Id               int            IDENTITY(1, 1) NOT NULL,
    [Date]           datetime       NOT NULL,
    Distance         decimal(9, 4)  NOT NULL,
    StartTime        datetime       NOT NULL,
    EndTime          datetime       NOT NULL,
    Duration         AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    PathEndTime      datetime       NOT NULL,
    PathDuration     AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, PathEndTime), 0), 0),
    RestDuration     AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, PathEndTime, EndTime), 0), 0),
    AverageHR        int            NOT NULL,
    MaxHR            int            NOT NULL,
    ElevationGain    int            NOT NULL,
    MaxSpeed         decimal(9, 4)  NOT NULL CONSTRAINT DF_RecreationalRun_MaxSpeed DEFAULT ((20)),
    Wind             nvarchar(255)  NOT NULL,
    Temperature      int            NOT NULL,
    Precipitation    bit            NOT NULL,
    ShoeId           int            NOT NULL,
    RouteId          int            NOT NULL,
    GpxJsonId        int            NULL,
    Notes            nvarchar(4000) NULL,

    CONSTRAINT PK_RecreationalRun PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_RecreationalRun_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_RecreationalRun_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT FK_RecreationalRun_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id),
    CONSTRAINT CK_RecreationalRun_RestNotNegative CHECK (PathEndTime <= EndTime)
);
GO
