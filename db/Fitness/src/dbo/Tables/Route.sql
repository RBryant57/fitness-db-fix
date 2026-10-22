CREATE TABLE [dbo].[Route] (
    [Id]     INT             IDENTITY (1, 1) NOT NULL,
    [Name]   NVARCHAR (50)   NOT NULL,
    [City]   NVARCHAR (50)   NOT NULL,
    [State]  CHAR (2)        NOT NULL,
    [TypeId] INT             CONSTRAINT [DF_Route_TypeId] DEFAULT ((1)) NOT NULL,
    [Rating] INT             CONSTRAINT [DF_Route_Rating] DEFAULT ((5)) NOT NULL,
    [Notes]  NVARCHAR (4000) NULL,
    CONSTRAINT [PK_Route] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CK_Route_Name] CHECK (NOT [Name] like ''),
    CONSTRAINT [FK_Route_Type] FOREIGN KEY ([TypeId]) REFERENCES [dbo].[RouteType] ([Id])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UNIQUE_Route_Name]
    ON [dbo].[Route]([Name] ASC) WITH (ALLOW_PAGE_LOCKS = OFF);


GO

