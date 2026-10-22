-- dbo.TrainingWalk, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- Removed: WalkTimeHours, WalkTimeMinutes, WalkTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), text in the form hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- In the dacpac these foreign keys are not trusted (created WITH NOCHECK): FK_TrainingWalk_GpxJson, FK_TrainingWalk_Route, FK_TrainingWalk_Shoe.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.TrainingWalk
(
    Id                 int            IDENTITY(1, 1) NOT NULL,
    [Date]             datetime       NOT NULL,
    Distance           decimal(9, 4)  NOT NULL,
    StartTime          datetime       NOT NULL,
    EndTime            datetime       NOT NULL,
    Duration           AS CONCAT(CASE WHEN DATEDIFF(second, StartTime, EndTime) / 3600 < 10 THEN '0' ELSE '' END,
                                 DATEDIFF(second, StartTime, EndTime) / 3600, ':',
                                 RIGHT(CONCAT('0', DATEDIFF(second, StartTime, EndTime) % 3600 / 60), 2), ':',
                                 RIGHT(CONCAT('0', DATEDIFF(second, StartTime, EndTime) % 60), 2)),
    AverageHR          int            NOT NULL,
    MaxHR              int            NOT NULL,
    ElevationGain      int            NOT NULL,
    MaxSpeed           decimal(9, 4)  NOT NULL CONSTRAINT DF_TrainingWalk_MaxSpeed DEFAULT ((3)),
    WindSpeed          int            NOT NULL,
    WindDirection      nvarchar(3)    NOT NULL,
    Temperature        int            NOT NULL,
    Precipitation      bit            NOT NULL,
    ShoeId             int            NOT NULL CONSTRAINT DF_TrainingWalk_ShoeId DEFAULT ((2)),
    RouteId            int            NOT NULL,
    NumberOfAttempts   int            NOT NULL CONSTRAINT DF_TrainingWalk_NumberOfAttempts DEFAULT ((0)),
    NumberOfSuccesses  int            NOT NULL CONSTRAINT DF_TrainingWalk_NumberOfSuccesses DEFAULT ((0)),
    GpxJsonId          int            NULL,
    Notes              nvarchar(4000) NULL,

    CONSTRAINT PK_TrainingWalk PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TrainingWalk_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_TrainingWalk_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT FK_TrainingWalk_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id)
);
GO

-- Tables that reference dbo.TrainingWalk:
--   dbo.TrainingWalkGPX -> FK_TrainingWalkGPX_TrainingWalk
