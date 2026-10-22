CREATE TABLE [dbo].[TrainingWalkGPX] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [TrainingWalkId] INT             NOT NULL,
    [GPX]            NVARCHAR (MAX)  NOT NULL,
    [Notes]          NVARCHAR (4000) NULL,
    CONSTRAINT [PK_TrainingWalkGPX] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_TrainingWalkGPX_TrainingWalk] FOREIGN KEY ([TrainingWalkId]) REFERENCES [dbo].[TrainingWalk] ([Id])
);


GO

