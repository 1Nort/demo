/*
  Модуль 2. Шифрование паролей.

  Скрипт создает ключи шифрования, переносит открытые пароли из Users.PasswordPlain
  в Users.PasswordEncrypted и показывает контрольный вывод с расшифровкой.
*/

USE BD;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MasterKey_Strong_2026!';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'UsersPasswordCertificate')
BEGIN
    CREATE CERTIFICATE UsersPasswordCertificate
    WITH SUBJECT = N'Certificate for Users passwords';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'UsersPasswordKey')
BEGIN
    CREATE SYMMETRIC KEY UsersPasswordKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE UsersPasswordCertificate;
END;
GO

OPEN SYMMETRIC KEY UsersPasswordKey
DECRYPTION BY CERTIFICATE UsersPasswordCertificate;

UPDATE dbo.Users
SET PasswordEncrypted = EncryptByKey(Key_GUID(N'UsersPasswordKey'), CONVERT(nvarchar(20), PasswordPlain))
WHERE PasswordPlain IS NOT NULL
  AND PasswordEncrypted IS NULL;

UPDATE dbo.Users
SET PasswordPlain = NULL
WHERE PasswordEncrypted IS NOT NULL;

SELECT
    UserId,
    LoginName,
    CONVERT(nvarchar(20), DecryptByKey(PasswordEncrypted)) AS DecryptedPassword,
    PasswordEncrypted
FROM dbo.Users
ORDER BY UserId;

CLOSE SYMMETRIC KEY UsersPasswordKey;
GO

