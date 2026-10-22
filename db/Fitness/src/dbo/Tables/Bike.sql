CREATE TABLE [dbo].[Bike] (
    [Id]              INT             IDENTITY (1, 1) NOT NULL,
    [Name]            VARCHAR (50)    NOT NULL,
    [ManufacturerId]  INT             NOT NULL,
    [TypeId]          INT             NOT NULL,
    [AcquisitionDate] DATETIME        NOT NULL,
    [BaseMiles]       INT             NOT NULL,
    [Notes]           NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Bike] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CK_Bike_Id] CHECK ([Id]>(0)),
    CONSTRAINT [FK_Bike_BikeType] FOREIGN KEY ([TypeId]) REFERENCES [dbo].[BikeType] ([Id]),
    CONSTRAINT [FK_Bike_Manufacturer] FOREIGN KEY ([ManufacturerId]) REFERENCES [dbo].[Manufacturer] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Bike_Name]
    ON [dbo].[Bike]([Name] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

