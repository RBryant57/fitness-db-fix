CREATE TABLE [dbo].[TrainingWalk] (
    [Id]                INT             IDENTITY (1, 1) NOT NULL,
    [Date]              DATETIME        NOT NULL,
    [Distance]          DECIMAL (9, 4)  NOT NULL,
    [StartTime]         DATETIME        NOT NULL,
    [EndTime]           DATETIME        NOT NULL,
    [WalkTimeHours]     INT             NOT NULL,
    [WalkTimeMinutes]   INT             NOT NULL,
    [WalkTimeSeconds]   INT             NOT NULL,
    [AverageHR]         INT             NOT NULL,
    [MaxHR]             INT             NOT NULL,
    [ElevationGain]     INT             NOT NULL,
    [MaxSpeed]          DECIMAL (9, 4)  CONSTRAINT [DF_TrainingWalk_MaxSpeed] DEFAULT ((3)) NOT NULL,
    [WindSpeed]         INT             NOT NULL,
    [WindDirection]     NVARCHAR (3)    NOT NULL,
    [Temperature]       INT             NOT NULL,
    [Precipitation]     BIT             NOT NULL,
    [ShoeId]            INT             CONSTRAINT [DF_TrainingWalk_ShoeId] DEFAULT ((2)) NOT NULL,
    [RouteId]           INT             NOT NULL,
    [NumberOfAttempts]  INT             CONSTRAINT [DF_TrainingWalk_NumberOfAttempts] DEFAULT ((0)) NOT NULL,
    [NumberOfSuccesses] INT             CONSTRAINT [DF_TrainingWalk_NumberOfSuccesses] DEFAULT ((0)) NOT NULL,
    [GpxJsonId]         INT             NULL,
    [Notes]             NVARCHAR (4000) NULL,
    CONSTRAINT [PK_TrainingWalk] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_TrainingWalk_GpxJson] FOREIGN KEY ([GpxJsonId]) REFERENCES [dbo].[GpxJson] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_TrainingWalk_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id]),
    CONSTRAINT [FK_TrainingWalk_Shoe] FOREIGN KEY ([ShoeId]) REFERENCES [dbo].[Shoe] ([Id])
);


GO

