-- dbo.TreadmillRun, as defined in production (dacpac extracted 2026-10-21) with the S5 change applied.
-- Removed: RunTimeHours, RunTimeMinutes, RunTimeSeconds.
-- Removed with them: no constraints or defaults.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.TreadmillRun
(
    Id              int            IDENTITY(1, 1) NOT NULL,
    [Date]          datetime       NOT NULL,
    Distance        decimal(9, 4)  NOT NULL,
    StartTime       datetime       NOT NULL,
    EndTime         datetime       NOT NULL,
    Duration        AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    AverageHR       int            NOT NULL,
    MaxHR           int            NOT NULL,
    ElevationGain   int            NOT NULL,
    ShoeId          int            NOT NULL,
    Notes           nvarchar(4000) NULL,

    CONSTRAINT PK_Treadmill PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TreadmillRun_Shoe FOREIGN KEY (ShoeId) REFERENCES dbo.Shoe (Id)
);
GO
