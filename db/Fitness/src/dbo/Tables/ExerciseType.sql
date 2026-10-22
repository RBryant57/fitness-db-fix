CREATE TABLE [dbo].[ExerciseType] (
    [Id]   INT           IDENTITY (1, 1) NOT NULL,
    [Name] NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_ExerciseType] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

