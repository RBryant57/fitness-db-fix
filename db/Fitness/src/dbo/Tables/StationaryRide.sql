CREATE TABLE [dbo].[StationaryRide] (
    [Id]              INT             IDENTITY (1, 1) NOT NULL,
    [Date]            DATETIME        NOT NULL,
    [StartOdometer]   INT             NOT NULL,
    [EndOdometer]     INT             NOT NULL,
    [Distance]        DECIMAL (9, 4)  NULL,
    [StartTime]       DATETIME        NOT NULL,
    [EndTime]         DATETIME        NOT NULL,
    [RideTimeHours]   INT             NOT NULL,
    [RideTimeMinutes] INT             NOT NULL,
    [RideTimeSeconds] INT             NOT NULL,
    [AverageHR]       INT             NOT NULL,
    [MaxHR]           INT             NOT NULL,
    [AverageCadence]  INT             NOT NULL,
    [BikeId]          INT             NULL,
    [Notes]           NVARCHAR (4000) NULL,
    CONSTRAINT [PK_StationaryRide] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_StationaryRide_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id])
);


GO

