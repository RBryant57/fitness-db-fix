CREATE TABLE [dbo].[RecreationalWalk] (
    [Id]              INT             IDENTITY (1, 1) NOT NULL,
    [Date]            DATETIME        NOT NULL,
    [Distance]        DECIMAL (9, 4)  NOT NULL,
    [StartTime]       DATETIME        NOT NULL,
    [EndTime]         DATETIME        NOT NULL,
    [WalkTimeHours]   INT             NOT NULL,
    [WalkTimeMinutes] INT             NOT NULL,
    [WalkTimeSeconds] INT             NOT NULL,
    [PathEndTime]     DATETIME        NOT NULL,
    [PathTimeHours]   INT             NOT NULL,
    [PathTimeMinutes] INT             NOT NULL,
    [PathTimeSeconds] INT             NOT NULL,
    [AverageHR]       INT             NOT NULL,
    [MaxHR]           INT             NOT NULL,
    [ElevationGain]   INT             NOT NULL,
    [MaxSpeed]        DECIMAL (9, 4)  CONSTRAINT [DF_RecreationalWalk_MaxSpeed] DEFAULT ((3)) NOT NULL,
    [Wind]            NVARCHAR (255)  NOT NULL,
    [Temperature]     INT             NOT NULL,
    [Precipitation]   BIT             NOT NULL,
    [ShoeId]          INT             NOT NULL,
    [RouteId]         INT             NOT NULL,
    [GpxJsonId]       INT             NULL,
    [Notes]           NVARCHAR (4000) NULL,
    CONSTRAINT [PK_RecreationalWalk] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RecreationalWalk_GpxJsonId] FOREIGN KEY ([GpxJsonId]) REFERENCES [dbo].[GpxJson] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_RecreationalWalk_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id]),
    CONSTRAINT [FK_RecreationalWalk_Shoe] FOREIGN KEY ([ShoeId]) REFERENCES [dbo].[Shoe] ([Id])
);


GO

