CREATE TABLE [dbo].[TreadmillRun] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [Date]           DATETIME        NOT NULL,
    [Distance]       DECIMAL (9, 4)  NOT NULL,
    [StartTime]      DATETIME        NOT NULL,
    [EndTime]        DATETIME        NOT NULL,
    [RunTimeHours]   INT             NOT NULL,
    [RunTimeMinutes] INT             NOT NULL,
    [RunTimeSeconds] INT             NOT NULL,
    [AverageHR]      INT             NOT NULL,
    [MaxHR]          INT             NOT NULL,
    [ElevationGain]  INT             NOT NULL,
    [ShoeId]         INT             NOT NULL,
    [Notes]          NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Treadmill] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_TreadmillRun_Shoe] FOREIGN KEY ([ShoeId]) REFERENCES [dbo].[Shoe] ([Id])
);


GO

