CREATE TABLE [dbo].[BikePart] (
    [Id]              INT      IDENTITY (1, 1) NOT NULL,
    [BikeId]          INT      NOT NULL,
    [PartId]          INT      NOT NULL,
    [StartDate]       DATETIME NOT NULL,
    [EndDate]         DATETIME NULL,
    [OdometerReading] INT      NOT NULL,
    CONSTRAINT [PK_BikePart] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_BikePart_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id]),
    CONSTRAINT [FK_BikePart_Part] FOREIGN KEY ([PartId]) REFERENCES [dbo].[Part] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_BikePart]
    ON [dbo].[BikePart]([BikeId] ASC, [PartId] ASC, [OdometerReading] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

