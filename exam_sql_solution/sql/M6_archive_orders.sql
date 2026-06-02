/*
  Модуль 6. Архивация заказов покупателей за выбранный месяц.

  Пример: EXEC dbo.usp_ArchiveCustomerOrdersByMonth @ArchiveMonth = '2026-05-01';
  Будет создана таблица dbo.Order_may, в нее перенесутся заказы мая,
  после чего записи удалятся из основной таблицы CustomerOrders.
*/

USE ManufacturingDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ArchiveCustomerOrdersByMonth
    @ArchiveMonth date
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @monthStart date = DATEFROMPARTS(YEAR(@ArchiveMonth), MONTH(@ArchiveMonth), 1);
    DECLARE @monthEnd date = DATEADD(month, 1, @monthStart);
    DECLARE @monthName sysname = LOWER(FORMAT(@monthStart, 'MMM', 'en-US'));
    DECLARE @archiveTable sysname = CONCAT(N'Order_', @monthName);
    DECLARE @sql nvarchar(max);

    SET @sql = N'
        IF OBJECT_ID(N''dbo.' + QUOTENAME(@archiveTable) + N''', N''U'') IS NULL
        BEGIN
            CREATE TABLE dbo.' + QUOTENAME(@archiveTable) + N'
            (
                ArchiveId int IDENTITY(1,1) CONSTRAINT PK_' + @archiveTable + N' PRIMARY KEY,
                OrderId int NOT NULL,
                CustomerName nvarchar(120) NOT NULL,
                OrderDate date NOT NULL,
                PlannedFinishDate date NULL,
                ProductName nvarchar(120) NOT NULL,
                Quantity int NOT NULL,
                UnitPriceAtOrder decimal(12,2) NOT NULL,
                MaterialCostAtOrder decimal(12,2) NOT NULL,
                TotalAmount decimal(14,2) NOT NULL,
                ArchivedAt datetime2(0) NOT NULL CONSTRAINT DF_' + @archiveTable + N'_ArchivedAt DEFAULT SYSDATETIME()
            );
        END;

        INSERT INTO dbo.' + QUOTENAME(@archiveTable) + N'
        (
            OrderId, CustomerName, OrderDate, PlannedFinishDate, ProductName,
            Quantity, UnitPriceAtOrder, MaterialCostAtOrder, TotalAmount
        )
        SELECT
            co.OrderId,
            c.CustomerName,
            co.OrderDate,
            co.PlannedFinishDate,
            p.ProductName,
            oi.Quantity,
            oi.UnitPriceAtOrder,
            oi.MaterialCostAtOrder,
            co.TotalAmount
        FROM dbo.CustomerOrders AS co
        JOIN dbo.Customers AS c ON c.CustomerId = co.CustomerId
        JOIN dbo.OrderItems AS oi ON oi.OrderId = co.OrderId
        JOIN dbo.Products AS p ON p.ProductId = oi.ProductId
        WHERE co.OrderDate >= @monthStart
          AND co.OrderDate < @monthEnd;

        DELETE co
        FROM dbo.CustomerOrders AS co
        WHERE co.OrderDate >= @monthStart
          AND co.OrderDate < @monthEnd;';

    EXEC sys.sp_executesql
        @sql,
        N'@monthStart date, @monthEnd date',
        @monthStart = @monthStart,
        @monthEnd = @monthEnd;
END;
GO

EXEC dbo.usp_ArchiveCustomerOrdersByMonth @ArchiveMonth = '2026-05-01';
GO

