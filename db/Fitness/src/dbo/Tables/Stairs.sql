CREATE TABLE [dbo].[Stairs] (
    [Id]               INT             IDENTITY (1, 1) NOT NULL,
    [Date]             DATETIME        NOT NULL,
    [StairQuantity]    INT             NOT NULL,
    [StartTime]        DATETIME        NOT NULL,
    [EndTime]          DATETIME        NOT NULL,
    [StairTimeHours]   INT             NOT NULL,
    [StairTimeMinutes] INT             NOT NULL,
    [StairTimeSeconds] INT             NOT NULL,
    [AverageHR]        INT             NOT NULL,
    [MaxHR]            INT             NOT NULL,
    [ElevationGain]    INT             NOT NULL,
    [ShoeId]           INT             NOT NULL,
    [Notes]            NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Stairs] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_Stairs_Shoe] FOREIGN KEY ([ShoeId]) REFERENCES [dbo].[Shoe] ([Id])
);


GO

