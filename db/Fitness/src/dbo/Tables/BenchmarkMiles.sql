CREATE TABLE [dbo].[BenchmarkMiles] (
    [Id]       INT IDENTITY (1, 1) NOT NULL,
    [Year]     INT NOT NULL,
    [BikeId]   INT NOT NULL,
    [Odometer] INT NOT NULL,
    CONSTRAINT [PK_BenchmarkMiles] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_BenchmarkMiles_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id])
);


GO

