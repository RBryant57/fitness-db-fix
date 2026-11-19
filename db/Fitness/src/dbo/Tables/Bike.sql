CREATE TABLE [dbo].[Bike] (
    [Id]              INT             IDENTITY (1, 1) NOT NULL,
    [Name]            NVARCHAR (50)   NOT NULL,
    [ManufacturerId]  INT             NOT NULL,
    [TypeId]          INT             NOT NULL,
    [AcquisitionDate] DATE            NOT NULL,
    [BaseMiles]       INT             NOT NULL,
    [Notes]           NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Bike] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CK_Bike_Id] CHECK ([Id]>(0)),
    CONSTRAINT [FK_Bike_BikeType] FOREIGN KEY ([TypeId]) REFERENCES [dbo].[BikeType] ([Id]),
    CONSTRAINT [FK_Bike_Manufacturer] FOREIGN KEY ([ManufacturerId]) REFERENCES [dbo].[Manufacturer] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_Bike_Name]
    ON [dbo].[Bike]([Name] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

CREATE NONCLUSTERED INDEX [IX_Bike_TypeId]
    ON [dbo].[Bike]([TypeId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_Bike_ManufacturerId]
    ON [dbo].[Bike]([ManufacturerId] ASC);


GO
