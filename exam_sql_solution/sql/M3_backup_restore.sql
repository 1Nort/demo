/*
  Модуль 3. Резервное копирование и восстановление базы BD.

  Путь C:\SqlBackups должен существовать. При необходимости измените @backupFile.
*/

USE master;
GO

DECLARE @backupFile nvarchar(260) = N'C:\SqlBackups\BD_full.bak';

BACKUP DATABASE BD
TO DISK = @backupFile
WITH INIT, FORMAT, COMPRESSION, CHECKSUM, STATS = 10;
GO

/*
  Восстановление выполняйте отдельно, когда база не используется.
*/

USE master;
GO

DECLARE @restoreFile nvarchar(260) = N'C:\SqlBackups\BD_full.bak';

IF DB_ID(N'BD_RestoreTest') IS NOT NULL
BEGIN
    ALTER DATABASE BD_RestoreTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BD_RestoreTest;
END;

RESTORE DATABASE BD_RestoreTest
FROM DISK = @restoreFile
WITH
    MOVE N'BD' TO N'C:\SqlBackups\BD_RestoreTest.mdf',
    MOVE N'BD_log' TO N'C:\SqlBackups\BD_RestoreTest_log.ldf',
    CHECKSUM,
    RECOVERY,
    STATS = 10;
GO

