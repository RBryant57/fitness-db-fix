CREATE TABLE [dbo].[Manufacturer] (
    [Id]    INT             IDENTITY (1, 1) NOT NULL,
    [Name]  NVARCHAR (50)   NOT NULL,
    [Notes] NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Manufacturer] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CK_Manufacturer_Name] CHECK (NOT [Name] like '')
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Manufacturer_Name]
    ON [dbo].[Manufacturer]([Name] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

