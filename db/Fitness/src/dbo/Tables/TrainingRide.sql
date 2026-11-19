-- dbo.TrainingRide after the S5 rebuild: computed durations (time(0)) follow their end times.
-- 2026-11-18: [Date] is date and the times are datetime2(0) (S13); the S7 checks are included; the S11 defaults (ShoeId, MaxSpeed) are removed.
-- Removed: RideTimeHours, RideTimeMinutes, RideTimeSeconds.
-- Removed with them: CK_RideTimeHours, CK_RideTimeMinutes, CK_RideTimeSeconds, DF_TrainingRide_RideTimeHours, DF_TrainingRide_RideTimeMinutes, DF_TrainingRide_RideTimeSeconds.
-- Computed (not stored), time(0), shown as hh:mm:ss: Duration (StartTime to EndTime).
-- Everything else is unchanged from the dacpac (types, constraint names, defaults).
-- Changed: Notes is nvarchar(4000) (the agreed type for every Notes column).
CREATE TABLE dbo.TrainingRide
(
    Id                 int            IDENTITY(1, 1) NOT NULL,
    [Date]             date           NOT NULL,
    StartOdometer      int            NOT NULL,
    EndOdometer        int            NOT NULL,
    Distance           decimal(9, 4)  NULL,
    StartTime          datetime2(0)   NOT NULL,
    EndTime            datetime2(0)   NOT NULL,
    Duration           AS CONVERT(time(0), DATEADD(second, DATEDIFF(second, StartTime, EndTime), 0), 0),
    AverageHR          int            NOT NULL,
    MaxHR              int            NOT NULL,
    AverageCadence     int            NOT NULL,
    ElevationGain      int            NOT NULL,
    MaxSpeed           decimal(9, 4)  NOT NULL,
    WindSpeed          int            NOT NULL,
    WindDirection      nvarchar(3)    NOT NULL,
    Temperature        int            NOT NULL,
    Precipitation      bit            NOT NULL,
    BikeId             int            NOT NULL,
    RouteId            int            NOT NULL,
    NumberOfAttempts   int            NOT NULL CONSTRAINT DF_TrainingRide_NumberOfAttempts DEFAULT ((0)),
    NumberOfSuccesses  int            NOT NULL CONSTRAINT DF_TrainingRide_NumberOfSuccesses DEFAULT ((0)),
    GpxJsonId          int            NULL,
    Notes              nvarchar(4000) NULL,

    CONSTRAINT PK_TrainingRide PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_TrainingRide_Bike FOREIGN KEY (BikeId) REFERENCES dbo.Bike (Id),
    CONSTRAINT FK_TrainingRide_GpxJson FOREIGN KEY (GpxJsonId) REFERENCES dbo.GpxJson (Id) ON DELETE CASCADE,
    CONSTRAINT FK_TrainingRide_Route FOREIGN KEY (RouteId) REFERENCES dbo.Route (Id),
    CONSTRAINT CK_TrainingRide_AverageCadence CHECK (AverageCadence>(0) AND AverageCadence<(200)),
    CONSTRAINT CK_TrainingRide_AverageHR CHECK (AverageHR>(0) AND AverageHR<(220)),
    CONSTRAINT CK_TrainingRide_EndOdometer CHECK (EndOdometer>(0)),
    CONSTRAINT CK_TrainingRide_MaxHR CHECK (MaxHR>(0) AND MaxHR<(220)),
    CONSTRAINT CK_TrainingRide_Miles CHECK (EndOdometer>StartOdometer),
    CONSTRAINT CK_TrainingRide_StartOdometer CHECK (StartOdometer>=(0)),
    CONSTRAINT CK_TrainingRide_WindSpeed CHECK (WindSpeed>=(0)),
    CONSTRAINT CK_TrainingRide_MaxHRAboveAverage CHECK ([MaxHR]>=[AverageHR]),
    CONSTRAINT CK_TrainingRide_Times CHECK ([EndTime]>[StartTime]),
    CONSTRAINT CK_TrainingRide_Distance CHECK ([Distance] IS NULL OR [Distance]>(0)),
    CONSTRAINT CK_TrainingRide_ElevationGain CHECK ([ElevationGain]>=(0)),
    CONSTRAINT CK_TrainingRide_Temperature CHECK ([Temperature]>=(-60) AND [Temperature]<=(140))
);
GO

CREATE NONCLUSTERED INDEX [IX_TrainingRide_BikeId]
    ON [dbo].[TrainingRide]([BikeId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingRide_GpxJsonId]
    ON [dbo].[TrainingRide]([GpxJsonId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingRide_RouteId]
    ON [dbo].[TrainingRide]([RouteId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TrainingRide_Date]
    ON [dbo].[TrainingRide]([Date] ASC);


GO
