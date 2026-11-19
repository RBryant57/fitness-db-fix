-- dbo.RecreationalRun, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- 2026-11-18: [Date] is date and the times are datetime2(0) (S13); the S7 checks are included; the S11 defaults (ShoeId, MaxSpeed) are removed.
-- Removed: RunTimeHours, RunTimeMinutes, RunTimeSeconds, PathTimeHours, PathTimeMinutes, PathTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime), PathDuration (StartTime to PathEndTime), RestDuration (PathEndTime to EndTime).
-- Check CK_RecreationalRun_RestNotNegative: PathEndTime may not be after EndTime (rest time cannot be negative).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- In the dacpac these foreign keys are not trusted (created WITH NOCHECK): FK_RecreationalRun_GpxJson, FK_RecreationalRun_Route, FK_RecreationalRun_Shoe.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.RecreationalRun
(
    Id               int            IDENTITY(1, 1) NOT NULL,
    [Date]           date           NOT NULL,
    Distance         decimal(9, 4)  NOT NULL,
    StartTime        datetime2(0)   NOT NULL,
    EndTime          datetime2(0)   NOT NULL,
    Duration         AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    PathEndTime      datetime2(0)   NOT NULL,
    PathDuration     AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, PathEndTime), 0), 0),
    RestDuration     AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, PathEndTime, EndTime), 0), 0),
    AverageHR        int            NOT NULL,
    MaxHR            int            NOT NULL,
    ElevationGain    int            NOT NULL,
    MaxSpeed         decimal(9, 4)  NOT NULL,
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
    CONSTRAINT CK_RecreationalRun_RestNotNegative CHECK (PathEndTime <= EndTime),
    CONSTRAINT CK_RecreationalRun_AverageHR CHECK ([AverageHR]>=(0) AND [AverageHR]<=(250)),
    CONSTRAINT CK_RecreationalRun_MaxHR CHECK ([MaxHR]>=(0) AND [MaxHR]<=(250)),
    CONSTRAINT CK_RecreationalRun_MaxHRAboveAverage CHECK ([MaxHR]>=[AverageHR]),
    CONSTRAINT CK_RecreationalRun_Times CHECK ([EndTime]>[StartTime]),
    CONSTRAINT CK_RecreationalRun_Distance CHECK ([Distance]>(0)),
    CONSTRAINT CK_RecreationalRun_ElevationGain CHECK ([ElevationGain]>=(0)),
    CONSTRAINT CK_RecreationalRun_Temperature CHECK ([Temperature]>=(-60) AND [Temperature]<=(140))
);
GO

-- Tables that reference dbo.RecreationalRun:
--   dbo.RecreationalRunGPX -> FK_RecreationalRunGPX_RecreationalRun
