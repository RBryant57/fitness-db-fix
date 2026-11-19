CREATE TABLE [dbo].[Shoe] (
    [Id]              INT             IDENTITY (1, 1) NOT NULL,
    [Name]            NVARCHAR (50)   NOT NULL,
    [ManufacturerId]  INT             NOT NULL,
    [ShoeTypeId]      INT             NOT NULL,
    [AcquisitionDate] DATE            NOT NULL,
    [RetireDate]      DATE            NULL,
    [Notes]           NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Shoe] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_Shoe_Manufacturer] FOREIGN KEY ([ManufacturerId]) REFERENCES [dbo].[Manufacturer] ([Id]),
    CONSTRAINT [FK_Shoe_ShoeType] FOREIGN KEY ([ShoeTypeId]) REFERENCES [dbo].[ShoeType] ([Id])
);


GO

CREATE NONCLUSTERED INDEX [IX_Shoe_ManufacturerId]
    ON [dbo].[Shoe]([ManufacturerId] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_Shoe_ShoeTypeId]
    ON [dbo].[Shoe]([ShoeTypeId] ASC);


GO
