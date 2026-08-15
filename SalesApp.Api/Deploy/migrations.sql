IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE TABLE [Roles] (
        [Id] int NOT NULL IDENTITY,
        [Name] nvarchar(50) NOT NULL,
        CONSTRAINT [PK_Roles] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE TABLE [Users] (
        [Id] int NOT NULL IDENTITY,
        [Username] nvarchar(100) NOT NULL,
        [PasswordHash] nvarchar(max) NOT NULL,
        [SalesEmployeeCode] nvarchar(20) NULL,
        [IsActive] bit NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE TABLE [AuditLogs] (
        [Id] int NOT NULL IDENTITY,
        [UserId] int NOT NULL,
        [Action] nvarchar(100) NOT NULL,
        [Timestamp] datetime2 NOT NULL,
        [Details] nvarchar(max) NULL,
        CONSTRAINT [PK_AuditLogs] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_AuditLogs_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE TABLE [Parameters] (
        [Id] int NOT NULL IDENTITY,
        [Key] nvarchar(150) NOT NULL,
        [Value] nvarchar(max) NOT NULL,
        [IsEncrypted] bit NOT NULL,
        [Group] nvarchar(50) NOT NULL,
        [Description] nvarchar(300) NULL,
        [UpdatedAt] datetime2 NOT NULL,
        [UpdatedById] int NULL,
        CONSTRAINT [PK_Parameters] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Parameters_Users_UpdatedById] FOREIGN KEY ([UpdatedById]) REFERENCES [Users] ([Id]) ON DELETE SET NULL
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE TABLE [UserRoles] (
        [UserId] int NOT NULL,
        [RoleId] int NOT NULL,
        CONSTRAINT [PK_UserRoles] PRIMARY KEY ([UserId], [RoleId]),
        CONSTRAINT [FK_UserRoles_Roles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [Roles] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_UserRoles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE TABLE [UserSalesSeries] (
        [Id] int NOT NULL IDENTITY,
        [UserId] int NOT NULL,
        [SapSeriesId] int NOT NULL,
        [SapSeriesName] nvarchar(100) NOT NULL,
        CONSTRAINT [PK_UserSalesSeries] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_UserSalesSeries_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    IF EXISTS (SELECT * FROM [sys].[identity_columns] WHERE [name] IN (N'Id', N'Description', N'Group', N'IsEncrypted', N'Key', N'UpdatedAt', N'UpdatedById', N'Value') AND [object_id] = OBJECT_ID(N'[Parameters]'))
        SET IDENTITY_INSERT [Parameters] ON;
    EXEC(N'INSERT INTO [Parameters] ([Id], [Description], [Group], [IsEncrypted], [Key], [UpdatedAt], [UpdatedById], [Value])
    VALUES (1, N''Service Layer base URL'', N''Sap'', CAST(0 AS bit), N''Sap:ServiceLayer:BaseUrl'', ''2026-01-01T00:00:00.0000000'', NULL, N''''),
    (2, N''SAP company database name'', N''Sap'', CAST(0 AS bit), N''Sap:ServiceLayer:CompanyDb'', ''2026-01-01T00:00:00.0000000'', NULL, N''''),
    (3, N''Integration user for Service Layer'', N''Sap'', CAST(1 AS bit), N''Sap:ServiceLayer:Username'', ''2026-01-01T00:00:00.0000000'', NULL, N''''),
    (4, N''Integration user password'', N''Sap'', CAST(1 AS bit), N''Sap:ServiceLayer:Password'', ''2026-01-01T00:00:00.0000000'', NULL, N''''),
    (5, N''Minutes before B1SESSION expires'', N''Sap'', CAST(0 AS bit), N''Sap:ServiceLayer:SessionTimeoutMinutes'', ''2026-01-01T00:00:00.0000000'', NULL, N''30''),
    (6, N''Max concurrent Service Layer sessions'', N''Sap'', CAST(0 AS bit), N''Sap:ServiceLayer:MaxPoolSessions'', ''2026-01-01T00:00:00.0000000'', NULL, N''10'')');
    IF EXISTS (SELECT * FROM [sys].[identity_columns] WHERE [name] IN (N'Id', N'Description', N'Group', N'IsEncrypted', N'Key', N'UpdatedAt', N'UpdatedById', N'Value') AND [object_id] = OBJECT_ID(N'[Parameters]'))
        SET IDENTITY_INSERT [Parameters] OFF;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    IF EXISTS (SELECT * FROM [sys].[identity_columns] WHERE [name] IN (N'Id', N'Name') AND [object_id] = OBJECT_ID(N'[Roles]'))
        SET IDENTITY_INSERT [Roles] ON;
    EXEC(N'INSERT INTO [Roles] ([Id], [Name])
    VALUES (1, N''Salesperson''),
    (2, N''Supervisor''),
    (3, N''Administrator'')');
    IF EXISTS (SELECT * FROM [sys].[identity_columns] WHERE [name] IN (N'Id', N'Name') AND [object_id] = OBJECT_ID(N'[Roles]'))
        SET IDENTITY_INSERT [Roles] OFF;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_AuditLogs_UserId] ON [AuditLogs] ([UserId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Parameters_Key] ON [Parameters] ([Key]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Parameters_UpdatedById] ON [Parameters] ([UpdatedById]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Roles_Name] ON [Roles] ([Name]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_UserRoles_RoleId] ON [UserRoles] ([RoleId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Users_Username] ON [Users] ([Username]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_UserSalesSeries_UserId_SapSeriesId] ON [UserSalesSeries] ([UserId], [SapSeriesId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260806130351_InitialCreate'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260806130351_InitialCreate', N'8.0.29');
END;
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260808031412_AddDataProtectionKeys'
)
BEGIN
    CREATE TABLE [DataProtectionKeys] (
        [Id] int NOT NULL IDENTITY,
        [FriendlyName] nvarchar(max) NULL,
        [Xml] nvarchar(max) NULL,
        CONSTRAINT [PK_DataProtectionKeys] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260808031412_AddDataProtectionKeys'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260808031412_AddDataProtectionKeys', N'8.0.29');
END;
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260811113117_AddCatalogCache'
)
BEGIN
    CREATE TABLE [CatalogCache] (
        [Id] int NOT NULL IDENTITY,
        [CatalogType] nvarchar(20) NOT NULL,
        [Code] int NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        [CachedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_CatalogCache] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260811113117_AddCatalogCache'
)
BEGIN
    IF EXISTS (SELECT * FROM [sys].[identity_columns] WHERE [name] IN (N'Id', N'Description', N'Group', N'IsEncrypted', N'Key', N'UpdatedAt', N'UpdatedById', N'Value') AND [object_id] = OBJECT_ID(N'[Parameters]'))
        SET IDENTITY_INSERT [Parameters] ON;
    EXEC(N'INSERT INTO [Parameters] ([Id], [Description], [Group], [IsEncrypted], [Key], [UpdatedAt], [UpdatedById], [Value])
    VALUES (7, N''Hours before a cached SAP catalog name (price list / payment terms) is refreshed'', N''Catalog'', CAST(0 AS bit), N''Catalog:CacheTtlHours'', ''2026-01-01T00:00:00.0000000'', NULL, N''6'')');
    IF EXISTS (SELECT * FROM [sys].[identity_columns] WHERE [name] IN (N'Id', N'Description', N'Group', N'IsEncrypted', N'Key', N'UpdatedAt', N'UpdatedById', N'Value') AND [object_id] = OBJECT_ID(N'[Parameters]'))
        SET IDENTITY_INSERT [Parameters] OFF;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260811113117_AddCatalogCache'
)
BEGIN
    CREATE UNIQUE INDEX [IX_CatalogCache_CatalogType_Code] ON [CatalogCache] ([CatalogType], [Code]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260811113117_AddCatalogCache'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260811113117_AddCatalogCache', N'8.0.29');
END;
GO

COMMIT;
GO

