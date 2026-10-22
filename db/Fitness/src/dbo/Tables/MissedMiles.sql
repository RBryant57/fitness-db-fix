CREATE TABLE [dbo].[MissedMiles] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [Date]           DATETIME        CONSTRAINT [DF_MissedMiles_Date] DEFAULT (((1)/(1))/(1990)) NOT NULL,
    [Miles]          DECIMAL (18, 2) NOT NULL,
    [ExerciseTypeId] INT             NOT NULL,
    [Notes]          NVARCHAR (4000) NULL,
    CONSTRAINT [PK_MissedMiles] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_MissedMiles_ExerciseType] FOREIGN KEY ([ExerciseTypeId]) REFERENCES [dbo].[ExerciseType] ([Id])
);


GO

