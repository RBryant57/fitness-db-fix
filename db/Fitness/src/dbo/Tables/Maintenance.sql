CREATE TABLE [dbo].[Maintenance] (
    [Id]          INT             IDENTITY (1, 1) NOT NULL,
    [BikeId]      INT             NOT NULL,
    [PartId]      INT             NOT NULL,
    [ActionTaken] NVARCHAR (50)   NOT NULL,
    [Date]        DATETIME        NOT NULL,
    [Odometer]    INT             NOT NULL,
    [Notes]       NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Maintenance] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_Maintenance_Bike] FOREIGN KEY ([BikeId]) REFERENCES [dbo].[Bike] ([Id]),
    CONSTRAINT [FK_Maintenance_Part] FOREIGN KEY ([PartId]) REFERENCES [dbo].[Part] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Maintenance]
    ON [dbo].[Maintenance]([BikeId] ASC, [PartId] ASC, [ActionTaken] ASC, [Odometer] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

