CREATE TABLE [dbo].[ShoeType] (
    [Id]     INT           IDENTITY (1, 1) NOT NULL,
    [EnumId] INT           NOT NULL,
    [Name]   NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_ShoeType] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

