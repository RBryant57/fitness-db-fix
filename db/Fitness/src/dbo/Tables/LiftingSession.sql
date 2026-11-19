CREATE TABLE [dbo].[LiftingSession] (
    [Id]           INT             IDENTITY (1, 1) NOT NULL,
    [Date]         DATE            NOT NULL,
    [CircuitId]    INT             NOT NULL,
    [NumberOfSets] INT             NOT NULL,
    [Notes]        NVARCHAR (4000) NULL,
    CONSTRAINT [PK_LiftingSession] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_LiftingSession_Circuit] FOREIGN KEY ([CircuitId]) REFERENCES [dbo].[Circuit] ([Id])
);


GO

CREATE NONCLUSTERED INDEX [IX_LiftingSession_CircuitId]
    ON [dbo].[LiftingSession]([CircuitId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_LiftingSession_Date]
    ON [dbo].[LiftingSession]([Date] ASC);


GO
