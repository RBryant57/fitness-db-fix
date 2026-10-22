CREATE TABLE [dbo].[CircuitComponent] (
    [Id]           INT             IDENTITY (1, 1) NOT NULL,
    [ExerciseName] NVARCHAR (100)  NOT NULL,
    [Notes]        NVARCHAR (4000) NULL,
    CONSTRAINT [PK_CircuitComponent] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_ExerciseName]
    ON [dbo].[CircuitComponent]([ExerciseName] ASC);


GO

