-- dbo.TrainingRun after the S5 rebuild: computed durations (time(0)) follow their end times.
-- Removed: RunTimeHours, RunTimeMinutes, RunTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
CREATE TABLE dbo.TrainingRun
(
    Id                 int            IDENTITY(1, 1) NOT NULL,
    [Date]             datetime       NOT NULL,
    Distance           decimal(9, 4)  NOT NULL,
    StartTime          datetime       NOT NULL,
    EndTime            datetime       NOT NULL,
    Duration           AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    AverageHR          int            NOT NULL,
    MaxHR              int            NOT NULL,
    ElevationGain      int            NOT NULL,
    MaxSpeed           decimal(9, 4)  NOT NULL CONSTRAINT DF_TrainingRun_MaxSpeed DEFAULT ((8)),
    WindSpeed          int            NOT NULL,
    WindDirection      nvarchar(3)    NOT NULL,
    Temperature        int            NOT NULL,
    Precipitation      bit            NOT NULL,
    ShoeId             int            NOT NULL CONSTRAINT DF_TrainingRun_ShoeId DEFAULT ((2)),
    RouteId            int            NOT NULL,
    NumberOfAttempts   int            NOT NULL CONSTRAINT DF_TrainingRun_NumberOfAttempts DEFAULT ((0)),
    NumberOfSuccesses  int            NOT NULL CONSTRAINT DF_TrainingRun_NumberOfSuccesses DEFAULT ((0)),
    GpxJsonId          int            NULL,
    Notes              nvarchar(4000) NULL,

    CONSTRAINT PK_TrainingRun PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TrainingRun_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_TrainingRun_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT FK_TrainingRun_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id)
);
GO
