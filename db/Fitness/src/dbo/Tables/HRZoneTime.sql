CREATE TABLE [dbo].[HRZoneTime] (
    [Id]          INT NOT NULL,
    [ZoneId]      INT NOT NULL,
    [RideId]      INT NOT NULL,
    [ZoneHours]   INT NOT NULL,
    [ZoneMinutes] INT NOT NULL,
    [ZoneSeconds] INT NOT NULL,
    CONSTRAINT [PK_HRZoneTime] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_HRZoneTime_HRZones] FOREIGN KEY ([ZoneId]) REFERENCES [dbo].[HRZones] ([Id]),
    CONSTRAINT [FK_HRZoneTime_TrainingRides] FOREIGN KEY ([RideId]) REFERENCES [dbo].[TrainingRide] ([Id])
);


GO

