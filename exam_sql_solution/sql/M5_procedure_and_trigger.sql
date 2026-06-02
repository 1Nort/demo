/*
  Модуль 5. Создание процедуры и триггера.
*/

USE ManufacturingDB;
GO

CREATE OR ALTER TRIGGER dbo.trg_OrderItems_RecalculateOrderTotal
ON dbo.OrderItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ChangedOrders AS
    (
        SELECT OrderId FROM inserted
        UNION
        SELECT OrderId FROM deleted
    ),
    MaterialCost AS
    (
        SELECT
            oi.OrderItemId,
            SUM(pm.QuantityPerProduct * m.UnitCost) AS ProductMaterialCost
        FROM dbo.OrderItems AS oi
        JOIN ChangedOrders AS co ON co.OrderId = oi.OrderId
        JOIN dbo.ProductMaterials AS pm ON pm.ProductId = oi.ProductId
        JOIN dbo.Materials AS m ON m.MaterialId = pm.MaterialId
        GROUP BY oi.OrderItemId
    )
    UPDATE oi
    SET MaterialCostAtOrder = ISNULL(mc.ProductMaterialCost, 0)
    FROM dbo.OrderItems AS oi
    JOIN MaterialCost AS mc ON mc.OrderItemId = oi.OrderItemId;

    UPDATE co
    SET TotalAmount = ISNULL(t.TotalAmount, 0)
    FROM dbo.CustomerOrders AS co
    JOIN ChangedOrders AS changed ON changed.OrderId = co.OrderId
    OUTER APPLY
    (
        SELECT SUM(oi.Quantity * (oi.UnitPriceAtOrder + oi.MaterialCostAtOrder)) AS TotalAmount
        FROM dbo.OrderItems AS oi
        WHERE oi.OrderId = co.OrderId
    ) AS t;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_OrderSummaryByPeriod
    @DateFrom date,
    @DateTo date
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(DISTINCT co.OrderId) AS TotalOrders,
        ISNULL(SUM(oi.Quantity), 0) AS TotalProductsQuantity,
        ISNULL(SUM(oi.Quantity * (oi.UnitPriceAtOrder + oi.MaterialCostAtOrder)), 0) AS TotalOrderAmount
    FROM dbo.CustomerOrders AS co
    LEFT JOIN dbo.OrderItems AS oi ON oi.OrderId = co.OrderId
    WHERE co.OrderDate >= @DateFrom
      AND co.OrderDate < DATEADD(day, 1, @DateTo);

    SELECT
        co.OrderId,
        c.CustomerName,
        co.OrderDate,
        SUM(oi.Quantity) AS ProductQuantity,
        co.TotalAmount
    FROM dbo.CustomerOrders AS co
    JOIN dbo.Customers AS c ON c.CustomerId = co.CustomerId
    LEFT JOIN dbo.OrderItems AS oi ON oi.OrderId = co.OrderId
    WHERE co.OrderDate >= @DateFrom
      AND co.OrderDate < DATEADD(day, 1, @DateTo)
    GROUP BY co.OrderId, c.CustomerName, co.OrderDate, co.TotalAmount
    ORDER BY co.OrderDate, co.OrderId;
END;
GO

UPDATE dbo.OrderItems
SET Quantity = Quantity
WHERE OrderItemId IN (SELECT TOP (1) OrderItemId FROM dbo.OrderItems ORDER BY OrderItemId);
GO

EXEC dbo.usp_OrderSummaryByPeriod @DateFrom = '2026-05-01', @DateTo = '2026-07-31';
GO

