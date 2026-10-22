CREATE TABLE [dbo].[RecreationalRunGPX] (
    [Id]                INT             IDENTITY (1, 1) NOT NULL,
    [RecreationalRunId] INT             NOT NULL,
    [GPX]               NVARCHAR (MAX)  NOT NULL,
    [Notes]             NVARCHAR (4000) NULL,
    CONSTRAINT [PK_RecreationalRunGPX] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_RecreationalRunGPX_RecreationalRun] FOREIGN KEY ([RecreationalRunId]) REFERENCES [dbo].[RecreationalRun] ([Id])
);


GO

