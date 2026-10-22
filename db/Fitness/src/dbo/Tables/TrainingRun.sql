CREATE TABLE [dbo].[TrainingRun] (
    [Id]                INT             IDENTITY (1, 1) NOT NULL,
    [Date]              DATETIME        NOT NULL,
    [Distance]          DECIMAL (9, 4)  NOT NULL,
    [StartTime]         DATETIME        NOT NULL,
    [EndTime]           DATETIME        NOT NULL,
    [RunTimeHours]      INT             NOT NULL,
    [RunTimeMinutes]    INT             NOT NULL,
    [RunTimeSeconds]    INT             NOT NULL,
    [AverageHR]         INT             NOT NULL,
    [MaxHR]             INT             NOT NULL,
    [ElevationGain]     INT             NOT NULL,
    [MaxSpeed]          DECIMAL (9, 4)  CONSTRAINT [DF_TrainingRun_MaxSpeed] DEFAULT ((8)) NOT NULL,
    [WindSpeed]         INT             NOT NULL,
    [WindDirection]     NVARCHAR (3)    NOT NULL,
    [Temperature]       INT             NOT NULL,
    [Precipitation]     BIT             NOT NULL,
    [ShoeId]            INT             CONSTRAINT [DF_TrainingRun_ShoeId] DEFAULT ((2)) NOT NULL,
    [RouteId]           INT             NOT NULL,
    [NumberOfAttempts]  INT             CONSTRAINT [DF_TrainingRun_NumberOfAttempts] DEFAULT ((0)) NOT NULL,
    [NumberOfSuccesses] INT             CONSTRAINT [DF_TrainingRun_NumberOfSuccesses] DEFAULT ((0)) NOT NULL,
    [GpxJsonId]         INT             NULL,
    [Notes]             NVARCHAR (4000) NULL,
    CONSTRAINT [PK_TrainingRun] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_TrainingRun_GpxJson] FOREIGN KEY ([GpxJsonId]) REFERENCES [dbo].[GpxJson] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_TrainingRun_Route] FOREIGN KEY ([RouteId]) REFERENCES [dbo].[Route] ([Id]),
    CONSTRAINT [FK_TrainingRun_Shoe] FOREIGN KEY ([ShoeId]) REFERENCES [dbo].[Shoe] ([Id])
);


GO

