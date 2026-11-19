-- dbo.TreadmillRun after the S5 rebuild: computed durations (time(0)) follow their end times.
-- 2026-11-18: [Date] is date and the times are datetime2(0) (S13); the S7 checks are included; the S11 defaults (ShoeId, MaxSpeed) are removed.
-- Removed: RunTimeHours, RunTimeMinutes, RunTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
CREATE TABLE dbo.TreadmillRun
(
    Id              int            IDENTITY(1, 1) NOT NULL,
    [Date]          date           NOT NULL,
    Distance        decimal(9, 4)  NOT NULL,
    StartTime       datetime2(0)   NOT NULL,
    EndTime         datetime2(0)   NOT NULL,
    Duration        AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    AverageHR       int            NOT NULL,
    MaxHR           int            NOT NULL,
    ElevationGain   int            NOT NULL,
    ShoeId          int            NOT NULL,
    Notes           nvarchar(4000) NULL,

    CONSTRAINT PK_TreadmillRun PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TreadmillRun_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id),
    CONSTRAINT CK_TreadmillRun_AverageHR CHECK ([AverageHR]>=(0) AND [AverageHR]<=(250)),
    CONSTRAINT CK_TreadmillRun_MaxHR CHECK ([MaxHR]>=(0) AND [MaxHR]<=(250)),
    CONSTRAINT CK_TreadmillRun_MaxHRAboveAverage CHECK ([MaxHR]>=[AverageHR]),
    CONSTRAINT CK_TreadmillRun_Times CHECK ([EndTime]>[StartTime]),
    CONSTRAINT CK_TreadmillRun_Distance CHECK ([Distance]>(0)),
    CONSTRAINT CK_TreadmillRun_ElevationGain CHECK ([ElevationGain]>=(0))
);
GO

CREATE NONCLUSTERED INDEX [IX_TreadmillRun_ShoeId]
    ON [dbo].[TreadmillRun]([ShoeId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TreadmillRun_Date]
    ON [dbo].[TreadmillRun]([Date] ASC);


GO
