CREATE TABLE [dbo].[TrainingRunGPX] (
    [Id]            INT             IDENTITY (1, 1) NOT NULL,
    [TrainingRunId] INT             NOT NULL,
    [GPX]           NVARCHAR (MAX)  NOT NULL,
    [Notes]         NVARCHAR (4000) NULL,
    CONSTRAINT [PK_TrainingRunGPX] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_TrainingRunGPX_TrainingRun] FOREIGN KEY ([TrainingRunId]) REFERENCES [dbo].[TrainingRun] ([Id])
);


GO

