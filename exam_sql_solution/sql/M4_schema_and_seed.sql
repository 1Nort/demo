/*
  Модуль 4. Проектирование и реализация базы данных на основе ER-диаграммы.

  Предметная область: производство продукции по спецификациям заказчика.
  Схема приведена к 3НФ: каждая сущность хранится отдельно, связи многие-ко-многим
  вынесены в ProductMaterials и OrderItems.
*/

USE master;
GO

IF DB_ID(N'ManufacturingDB') IS NULL
BEGIN
    CREATE DATABASE ManufacturingDB;
END;
GO

USE ManufacturingDB;
GO

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID(N'dbo.CustomerOrders', N'U') IS NOT NULL DROP TABLE dbo.CustomerOrders;
IF OBJECT_ID(N'dbo.ProductMaterials', N'U') IS NOT NULL DROP TABLE dbo.ProductMaterials;
IF OBJECT_ID(N'dbo.Products', N'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID(N'dbo.Materials', N'U') IS NOT NULL DROP TABLE dbo.Materials;
IF OBJECT_ID(N'dbo.Customers', N'U') IS NOT NULL DROP TABLE dbo.Customers;
GO

CREATE TABLE dbo.Customers
(
    CustomerId int IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY,
    CustomerName nvarchar(120) NOT NULL CONSTRAINT UQ_Customers_CustomerName UNIQUE,
    Phone nvarchar(30) NULL,
    Email nvarchar(120) NULL
);

CREATE TABLE dbo.Materials
(
    MaterialId int IDENTITY(1,1) CONSTRAINT PK_Materials PRIMARY KEY,
    MaterialName nvarchar(120) NOT NULL CONSTRAINT UQ_Materials_MaterialName UNIQUE,
    UnitName nvarchar(20) NOT NULL,
    UnitCost decimal(12,2) NOT NULL CONSTRAINT CK_Materials_UnitCost CHECK (UnitCost >= 0)
);

CREATE TABLE dbo.Products
(
    ProductId int IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY,
    ProductName nvarchar(120) NOT NULL CONSTRAINT UQ_Products_ProductName UNIQUE,
    Specification nvarchar(500) NOT NULL,
    SalePrice decimal(12,2) NOT NULL CONSTRAINT CK_Products_SalePrice CHECK (SalePrice >= 0)
);

CREATE TABLE dbo.ProductMaterials
(
    ProductId int NOT NULL,
    MaterialId int NOT NULL,
    QuantityPerProduct decimal(12,3) NOT NULL CONSTRAINT CK_ProductMaterials_Quantity CHECK (QuantityPerProduct > 0),
    CONSTRAINT PK_ProductMaterials PRIMARY KEY (ProductId, MaterialId),
    CONSTRAINT FK_ProductMaterials_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId),
    CONSTRAINT FK_ProductMaterials_Materials FOREIGN KEY (MaterialId) REFERENCES dbo.Materials(MaterialId)
);

CREATE TABLE dbo.CustomerOrders
(
    OrderId int IDENTITY(1,1) CONSTRAINT PK_CustomerOrders PRIMARY KEY,
    CustomerId int NOT NULL,
    OrderDate date NOT NULL,
    PlannedFinishDate date NULL,
    TotalAmount decimal(14,2) NOT NULL CONSTRAINT DF_CustomerOrders_TotalAmount DEFAULT 0,
    CONSTRAINT FK_CustomerOrders_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(CustomerId)
);

CREATE TABLE dbo.OrderItems
(
    OrderItemId int IDENTITY(1,1) CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderId int NOT NULL,
    ProductId int NOT NULL,
    Quantity int NOT NULL CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    UnitPriceAtOrder decimal(12,2) NOT NULL,
    MaterialCostAtOrder decimal(12,2) NOT NULL CONSTRAINT DF_OrderItems_MaterialCost DEFAULT 0,
    CONSTRAINT FK_OrderItems_CustomerOrders FOREIGN KEY (OrderId) REFERENCES dbo.CustomerOrders(OrderId) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId)
);
GO

INSERT INTO dbo.Customers (CustomerName, Phone, Email)
VALUES
    (N'ООО Астек', N'+79001234501', N'astek@example.ru'),
    (N'ИП Петров', N'+79001234502', N'petrov@example.ru'),
    (N'ООО Пламя', N'+79001234503', N'plamya@example.ru');

INSERT INTO dbo.Materials (MaterialName, UnitName, UnitCost)
VALUES
    (N'Сталь листовая', N'кг', 95.00),
    (N'Пластик ABS', N'кг', 180.00),
    (N'Краска порошковая', N'кг', 260.00);

INSERT INTO dbo.Products (ProductName, Specification, SalePrice)
VALUES
    (N'Корпус металлический', N'Сталь 2 мм, порошковая окраска', 2488.00),
    (N'Крышка защитная', N'ABS пластик, серый цвет', 1200.00),
    (N'Панель монтажная', N'Сталь 1 мм, отверстия по чертежу', 1560.00);

INSERT INTO dbo.ProductMaterials (ProductId, MaterialId, QuantityPerProduct)
VALUES
    (1, 1, 8.500), (1, 3, 0.300),
    (2, 2, 2.200),
    (3, 1, 4.000), (3, 3, 0.150);

INSERT INTO dbo.CustomerOrders (CustomerId, OrderDate, PlannedFinishDate)
VALUES
    (1, '2026-05-06', '2026-05-15'),
    (2, '2026-06-10', '2026-06-18'),
    (3, '2026-07-21', '2026-07-30');

INSERT INTO dbo.OrderItems (OrderId, ProductId, Quantity, UnitPriceAtOrder, MaterialCostAtOrder)
SELECT 1, 1, 10, p.SalePrice, 0 FROM dbo.Products AS p WHERE p.ProductId = 1
UNION ALL SELECT 1, 3, 4, p.SalePrice, 0 FROM dbo.Products AS p WHERE p.ProductId = 3
UNION ALL SELECT 2, 2, 15, p.SalePrice, 0 FROM dbo.Products AS p WHERE p.ProductId = 2
UNION ALL SELECT 3, 1, 20, p.SalePrice, 0 FROM dbo.Products AS p WHERE p.ProductId = 1;
GO

