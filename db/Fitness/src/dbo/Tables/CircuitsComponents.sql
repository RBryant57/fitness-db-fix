CREATE TABLE [dbo].[CircuitsComponents] (
    [Id]                 INT IDENTITY (1, 1) NOT NULL,
    [CircuitId]          INT NOT NULL,
    [CircuitComponentId] INT NOT NULL,
    CONSTRAINT [PK_CircuitsComponents] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_CircuitsComponents_Circuit] FOREIGN KEY ([CircuitId]) REFERENCES [dbo].[Circuit] ([Id]),
    CONSTRAINT [FK_CircuitsComponents_CircuitComponent] FOREIGN KEY ([CircuitComponentId]) REFERENCES [dbo].[CircuitComponent] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_CircuitId_CircuitComponentId]
    ON [dbo].[CircuitsComponents]([CircuitId] ASC, [CircuitComponentId] ASC);


GO

