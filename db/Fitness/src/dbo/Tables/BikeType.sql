CREATE TABLE [dbo].[BikeType] (
    [Id]     INT          IDENTITY (1, 1) NOT NULL,
    [EnumId] INT          NOT NULL,
    [Name]   NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_BikeType] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_BikeType_EnumId]
    ON [dbo].[BikeType]([EnumId] ASC);


GO

