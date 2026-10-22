CREATE TABLE [dbo].[RecreationalRun] (
    [Id]              INT             IDENTITY (1, 1) NOT NULL,
    [Date]            DATETIME        NOT NULL,
    [Distance]        DECIMAL (9, 4)  NOT NULL,
    [StartTime]       DATETIME        NOT NULL,
    [EndTime]         DATETIME        NOT NULL,
    [RunTimeHours]    INT             NOT NULL,
    [RunTimeMinutes]  INT             NOT NULL,
    [RunTimeSeconds]  INT             NOT NULL,
    [PathEndTime]     DATETIME        NOT NULL,
    [PathTimeHours]   INT             NOT NULL,
    [PathTimeMinutes] INT             NOT NULL,
    [PathTimeSeconds] INT             NOT NULL,
    [AverageHR]       INT             NOT NULL,
    [MaxHR]           INT             NOT NULL,
    [ElevationGain]   INT             NOT NULL,
    [MaxSpeed]        DECIMAL (9, 4)  CONSTRAINT [DF_RecreationalRun_MaxSpeed] DEFAULT ((20)) NOT NULL,
    [Wind]            NVARCHAR (255)  NOT NULL,
    [Temperature]     INT             NOT NULL,
    [Precipitation]   BIT             NOT NULL,
    [ShoeId]          INT             NOT NULL,
    [RouteId]         INT             NOT NULL,
    [GpxJsonId]       INT             NULL,
    [Notes]           NVARCHAR (4000) NULL,
    CONSTRAINT [PK_RecreationalRun] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RecreationalRun_GpxJson] FOREIGN KEY ([GpxJsonId]) REFERENCES [dbo].[GpxJson] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_RecreationalRun_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id]),
    CONSTRAINT [FK_RecreationalRun_Shoe] FOREIGN KEY ([ShoeId]) REFERENCES [dbo].[Shoe] ([Id])
);


GO

