CREATE TABLE [dbo].[LiftingSession] (
    [Id]           INT             IDENTITY (1, 1) NOT NULL,
    [Date]         DATETIME        NOT NULL,
    [CircuitId]    INT             NOT NULL,
    [NumberOfSets] INT             NOT NULL,
    [Notes]        NVARCHAR (4000) NULL,
    CONSTRAINT [PK_LiftSession] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_LiftSession_Circuit] FOREIGN KEY ([CircuitId]) REFERENCES [dbo].[Circuit] ([Id])
);


GO

