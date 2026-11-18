CREATE TABLE [dbo].[LiftingSession] (
    [Id]           INT             IDENTITY (1, 1) NOT NULL,
    [Date]         DATETIME        NOT NULL,
    [CircuitId]    INT             NOT NULL,
    [NumberOfSets] INT             NOT NULL,
    [Notes]        NVARCHAR (4000) NULL,
    CONSTRAINT [PK_LiftingSession] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_LiftingSession_Circuit] FOREIGN KEY ([CircuitId]) REFERENCES [dbo].[Circuit] ([Id])
);


GO

