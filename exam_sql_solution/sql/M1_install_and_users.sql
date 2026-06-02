/*
  Модуль 1. Установка и настройка SQL-сервера с автоматическим
  созданием пользователей и баз данных.

  Перед запуском при необходимости замените @serverNumber на номер рабочего места.
  Скрипт выполняется в SQL Server Management Studio под учетной записью администратора.
*/

USE master;
GO

DECLARE @serverNumber nvarchar(10) = N'05';
DECLARE @saPassword nvarchar(128) = N'De_' + @serverNumber;

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'sa')
BEGIN
    ALTER LOGIN sa ENABLE;
    DECLARE @saSql nvarchar(max) = N'ALTER LOGIN sa WITH PASSWORD = ' + QUOTENAME(@saPassword, '''') + N';';
    EXEC sys.sp_executesql @saSql;
END;

IF DB_ID(N'BD') IS NULL
BEGIN
    CREATE DATABASE BD;
END;
GO

USE BD;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users
    (
        UserId int IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
        LoginName sysname NOT NULL CONSTRAINT UQ_Users_LoginName UNIQUE,
        PasswordPlain nvarchar(20) NULL,
        PasswordEncrypted varbinary(max) NULL,
        CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSDATETIME()
    );
END;
GO

DECLARE @i int = 1;
DECLARE @login sysname;
DECLARE @dbName sysname;
DECLARE @password nvarchar(5);
DECLARE @sql nvarchar(max);

WHILE @i <= 10
BEGIN
    SET @login = CONCAT(N'user', @i);
    SET @dbName = CONCAT(N'BD', @i);
    SET @password = LEFT(REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N''), 5);

    IF DB_ID(@dbName) IS NULL
    BEGIN
        SET @sql = N'CREATE DATABASE ' + QUOTENAME(@dbName) + N';';
        EXEC sys.sp_executesql @sql;
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @login)
    BEGIN
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@login)
            + N' WITH PASSWORD = ' + QUOTENAME(@password, '''')
            + N', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
        EXEC sys.sp_executesql @sql;
    END;

    SET @sql = N'
        USE ' + QUOTENAME(@dbName) + N';
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''' + @login + N''')
            CREATE USER ' + QUOTENAME(@login) + N' FOR LOGIN ' + QUOTENAME(@login) + N';
        ALTER ROLE db_owner ADD MEMBER ' + QUOTENAME(@login) + N';';
    EXEC sys.sp_executesql @sql;

    SET @sql = N'
        USE BD;
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''' + @login + N''')
            CREATE USER ' + QUOTENAME(@login) + N' FOR LOGIN ' + QUOTENAME(@login) + N';';
    EXEC sys.sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM BD.dbo.Users WHERE LoginName = @login)
    BEGIN
        INSERT INTO BD.dbo.Users (LoginName, PasswordPlain)
        VALUES (@login, @password);
    END;

    SET @i += 1;
END;
GO

SELECT LoginName, PasswordPlain AS GeneratedPassword
FROM BD.dbo.Users
ORDER BY UserId;
