CREATE TABLE [dbo].[Part] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [ManufacturerId] INT             NOT NULL,
    [PartTypeId]     INT             NOT NULL,
    [Name]           NVARCHAR (50)   NOT NULL,
    [Notes]          NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Part] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CK_Part_Name] CHECK (NOT [Name] like ''),
    CONSTRAINT [FK_Part_Manufacturer] FOREIGN KEY ([ManufacturerId]) REFERENCES [dbo].[Manufacturer] ([Id]),
    CONSTRAINT [FK_Part_PartType] FOREIGN KEY ([PartTypeId]) REFERENCES [dbo].[PartType] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Part]
    ON [dbo].[Part]([ManufacturerId] ASC, [PartTypeId] ASC, [Name] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

