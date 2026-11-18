-- dbo.RecreationalWalk, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- Removed: WalkTimeHours, WalkTimeMinutes, WalkTimeSeconds, PathTimeHours, PathTimeMinutes, PathTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime), PathDuration (StartTime to PathEndTime), RestDuration (PathEndTime to EndTime).
-- Check CK_RecreationalWalk_RestNotNegative: PathEndTime may not be after EndTime (rest time cannot be negative).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- In the dacpac these foreign keys are not trusted (created WITH NOCHECK): FK_RecreationalWalk_GpxJson, FK_RecreationalWalk_Route, FK_RecreationalWalk_Shoe.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.RecreationalWalk
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
    MaxSpeed         decimal(9, 4)  NOT NULL CONSTRAINT DF_RecreationalWalk_MaxSpeed DEFAULT ((3)),
    Wind             nvarchar(255)  NOT NULL,
    Temperature      int            NOT NULL,
    Precipitation    bit            NOT NULL,
    ShoeId           int            NOT NULL,
    RouteId          int            NOT NULL,
    GpxJsonId        int            NULL,
    Notes            nvarchar(4000) NULL,

    CONSTRAINT PK_RecreationalWalk PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_RecreationalWalk_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_RecreationalWalk_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT FK_RecreationalWalk_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id),
    CONSTRAINT CK_RecreationalWalk_RestNotNegative CHECK (PathEndTime <= EndTime)
);
GO

-- Tables that reference dbo.RecreationalWalk:
--   dbo.RecreationalWalkGPX -> FK_RecreationalWalkGPX_RecreationalWalk
