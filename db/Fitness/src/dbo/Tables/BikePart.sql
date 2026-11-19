CREATE TABLE [dbo].[BikePart] (
    [Id]              INT      IDENTITY (1, 1) NOT NULL,
    [BikeId]          INT      NOT NULL,
    [PartId]          INT      NOT NULL,
    [StartDate]       DATE     NOT NULL,
    [EndDate]         DATE     NULL,
    [OdometerReading] INT      NOT NULL,
    CONSTRAINT [PK_BikePart] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_BikePart_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id]),
    CONSTRAINT [FK_BikePart_Part] FOREIGN KEY ([PartId]) REFERENCES [dbo].[Part] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_BikePart_BikeId_PartId_OdometerReading]
    ON [dbo].[BikePart]([BikeId] ASC, [PartId] ASC, [OdometerReading] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

CREATE NONCLUSTERED INDEX [IX_BikePart_PartId]
    ON [dbo].[BikePart]([PartId] ASC);


GO
