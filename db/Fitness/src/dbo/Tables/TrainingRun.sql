-- dbo.TrainingRun after the S5 rebuild: computed durations (time(0)) follow their end times.
-- 2026-11-18: [Date] is date and the times are datetime2(0) (S13); the S7 checks are included; the S11 defaults (ShoeId, MaxSpeed) are removed.
-- Removed: RunTimeHours, RunTimeMinutes, RunTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
CREATE TABLE dbo.TrainingRun
(
    Id                 int            IDENTITY(1, 1) NOT NULL,
    [Date]             date           NOT NULL,
    Distance           decimal(9, 4)  NOT NULL,
    StartTime          datetime2(0)   NOT NULL,
    EndTime            datetime2(0)   NOT NULL,
    Duration           AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    AverageHR          int            NOT NULL,
    MaxHR              int            NOT NULL,
    ElevationGain      int            NOT NULL,
    MaxSpeed           decimal(9, 4)  NOT NULL,
    WindSpeed          int            NOT NULL,
    WindDirection      nvarchar(3)    NOT NULL,
    Temperature        int            NOT NULL,
    Precipitation      bit            NOT NULL,
    ShoeId             int            NOT NULL,
    RouteId            int            NOT NULL,
    NumberOfAttempts   int            NOT NULL CONSTRAINT DF_TrainingRun_NumberOfAttempts DEFAULT ((0)),
    NumberOfSuccesses  int            NOT NULL CONSTRAINT DF_TrainingRun_NumberOfSuccesses DEFAULT ((0)),
    GpxJsonId          int            NULL,
    Notes              nvarchar(4000) NULL,

    CONSTRAINT PK_TrainingRun PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TrainingRun_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_TrainingRun_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT FK_TrainingRun_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id),
    CONSTRAINT CK_TrainingRun_AverageHR CHECK ([AverageHR]>=(0) AND [AverageHR]<=(250)),
    CONSTRAINT CK_TrainingRun_MaxHR CHECK ([MaxHR]>=(0) AND [MaxHR]<=(250)),
    CONSTRAINT CK_TrainingRun_MaxHRAboveAverage CHECK ([MaxHR]>=[AverageHR]),
    CONSTRAINT CK_TrainingRun_Times CHECK ([EndTime]>[StartTime]),
    CONSTRAINT CK_TrainingRun_Distance CHECK ([Distance]>(0)),
    CONSTRAINT CK_TrainingRun_ElevationGain CHECK ([ElevationGain]>=(0)),
    CONSTRAINT CK_TrainingRun_Temperature CHECK ([Temperature]>=(-60) AND [Temperature]<=(140)),
    CONSTRAINT CK_TrainingRun_WindSpeed CHECK ([WindSpeed]>=(0))
);
GO

CREATE NONCLUSTERED INDEX [IX_TrainingRun_GpxJsonId]
    ON [dbo].[TrainingRun]([GpxJsonId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingRun_RouteId]
    ON [dbo].[TrainingRun]([RouteId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingRun_ShoeId]
    ON [dbo].[TrainingRun]([ShoeId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingRun_Date]
    ON [dbo].[TrainingRun]([Date] ASC);


GO
