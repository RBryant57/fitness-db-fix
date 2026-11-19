-- dbo.TrainingWalk after the S5 rebuild: computed durations (time(0)) follow their end times.
-- 2026-11-18: [Date] is date and the times are datetime2(0) (S13); the S7 checks are included; the S11 defaults (ShoeId, MaxSpeed) are removed.
-- Removed: WalkTimeHours, WalkTimeMinutes, WalkTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
CREATE TABLE dbo.TrainingWalk
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
    NumberOfAttempts   int            NOT NULL CONSTRAINT DF_TrainingWalk_NumberOfAttempts DEFAULT ((0)),
    NumberOfSuccesses  int            NOT NULL CONSTRAINT DF_TrainingWalk_NumberOfSuccesses DEFAULT ((0)),
    GpxJsonId          int            NULL,
    Notes              nvarchar(4000) NULL,

    CONSTRAINT PK_TrainingWalk PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TrainingWalk_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_TrainingWalk_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT FK_TrainingWalk_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id),
    CONSTRAINT CK_TrainingWalk_AverageHR CHECK ([AverageHR]>=(0) AND [AverageHR]<=(250)),
    CONSTRAINT CK_TrainingWalk_MaxHR CHECK ([MaxHR]>=(0) AND [MaxHR]<=(250)),
    CONSTRAINT CK_TrainingWalk_MaxHRAboveAverage CHECK ([MaxHR]>=[AverageHR]),
    CONSTRAINT CK_TrainingWalk_Times CHECK ([EndTime]>[StartTime]),
    CONSTRAINT CK_TrainingWalk_Distance CHECK ([Distance]>(0)),
    CONSTRAINT CK_TrainingWalk_ElevationGain CHECK ([ElevationGain]>=(0)),
    CONSTRAINT CK_TrainingWalk_Temperature CHECK ([Temperature]>=(-60) AND [Temperature]<=(140)),
    CONSTRAINT CK_TrainingWalk_WindSpeed CHECK ([WindSpeed]>=(0))
);
GO

CREATE NONCLUSTERED INDEX [IX_TrainingWalk_GpxJsonId]
    ON [dbo].[TrainingWalk]([GpxJsonId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingWalk_RouteId]
    ON [dbo].[TrainingWalk]([RouteId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingWalk_ShoeId]
    ON [dbo].[TrainingWalk]([ShoeId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingWalk_Date]
    ON [dbo].[TrainingWalk]([Date] ASC);


GO
