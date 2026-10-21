CREATE DATABASE sales_db;
USE sales_db;
select * from customers;
select * from datetable;
select * from orderitems;
select * from orders;
select * from products;

SELECT COUNT(*) FROM Customers;
SELECT COUNT(*) FROM datetable;


CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100)
);

CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100),
    Price DECIMAL(10,2)
);

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    OrderDate DATE,

    FOREIGN KEY (CustomerID)
    REFERENCES Customers(CustomerID)
);

CREATE TABLE OrderItems (
    OrderLineID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,

    FOREIGN KEY (OrderID)
    REFERENCES Orders(OrderID),

    FOREIGN KEY (ProductID)
    REFERENCES Products(ProductID)
);

SHOW CREATE TABLE Orders;
SHOW CREATE TABLE OrderItems;

drop database shopdb;

SELECT *
FROM Customers
WHERE CustomerID IS NULL;
SELECT CustomerID, COUNT(*)
FROM Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1;

SELECT *
FROM OrderItems
WHERE Quantity < 0;

SELECT
    ProductID,
    SUM(Quantity) AS TotalQuantity
FROM OrderItems
GROUP BY ProductID
ORDER BY TotalQuantity DESC;


SHOW TABLES;
DESCRIBE customers;
DESCRIBE products;
DESCRIBE orders;
DESCRIBE orderitems;
DESCRIBE datetable;

SELECT
    ROUND(SUM(oi.Quantity * oi.UnitPrice *
        (1 - COALESCE(oi.DiscountPct, 0) / 100)), 2)
        AS TotalSales,

    ROUND(SUM(
        oi.Quantity * oi.UnitPrice *
        (1 - COALESCE(oi.DiscountPct, 0) / 100)
        - COALESCE(oi.TotalCost, oi.Quantity * p.UnitCost)
    ), 2) AS TotalProfit,

    COUNT(DISTINCT o.OrderID) AS TotalOrders,

    COUNT(DISTINCT o.CustomerID) AS TotalCustomers,

    SUM(oi.Quantity) AS UnitsSold,

    ROUND(
        100.0 * SUM(
            oi.Quantity * oi.UnitPrice *
            (1 - COALESCE(oi.DiscountPct, 0) / 100)
            - COALESCE(oi.TotalCost, oi.Quantity * p.UnitCost)
        ) /
        NULLIF(SUM(
            oi.Quantity * oi.UnitPrice *
            (1 - COALESCE(oi.DiscountPct, 0) / 100)
        ), 0), 2
    ) AS ProfitMarginPct

FROM orders o
JOIN orderitems oi ON o.OrderID = oi.OrderID
JOIN products p ON oi.ProductID = p.ProductID;


SELECT
    p.ProductName,
    p.Category,
    SUM(
        oi.Quantity * oi.UnitPrice *
        (1 - COALESCE(oi.DiscountPct, 0) / 100)
    ) AS TotalSales,
    SUM(
        oi.Quantity * oi.UnitPrice *
        (1 - COALESCE(oi.DiscountPct, 0) / 100)
        - COALESCE(oi.TotalCost, oi.Quantity * p.UnitCost)
    ) AS TotalProfit
FROM orderitems oi
JOIN products p ON oi.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName, p.Category
ORDER BY TotalSales DESC
LIMIT 10;

WITH CustomerRFM AS (
    SELECT
        c.CustomerID,
        c.CustomerName,
        DATEDIFF(CURDATE(), MAX(o.OrderDate)) AS RecencyDays,
        COUNT(DISTINCT o.OrderID) AS Frequency,
        SUM(
            oi.Quantity * oi.UnitPrice *
            (1 - COALESCE(oi.DiscountPct, 0) / 100)
        ) AS Monetary
    FROM customers c
    JOIN orders o ON c.CustomerID = o.CustomerID
    JOIN orderitems oi ON o.OrderID = oi.OrderID
    GROUP BY c.CustomerID, c.CustomerName
),
Scores AS (
    SELECT *,
        NTILE(5) OVER (
            ORDER BY RecencyDays DESC
        ) AS R_Score,
        NTILE(5) OVER (
            ORDER BY Frequency
        ) AS F_Score,
        NTILE(5) OVER (
            ORDER BY Monetary
        ) AS M_Score
    FROM CustomerRFM
)
SELECT *,
    CASE
        WHEN R_Score = 5 AND F_Score >= 4 AND M_Score >= 4
            THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 4
            THEN 'Loyal Customers'
        WHEN R_Score <= 2
            THEN 'At Risk'
        ELSE 'Regular Customers'
    END AS CustomerSegment
FROM Scores
ORDER BY R_Score DESC, F_Score DESC;

WITH MonthlySales AS (
    SELECT
        DATE_FORMAT(o.OrderDate, '%Y-%m-01') AS SalesMonth,
        SUM(
            oi.Quantity * oi.UnitPrice *
            (1 - COALESCE(oi.DiscountPct, 0) / 100)
        ) AS TotalSales
    FROM orders o
    JOIN orderitems oi
        ON o.OrderID = oi.OrderID
    GROUP BY DATE_FORMAT(o.OrderDate, '%Y-%m-01')
),
PreviousSales AS (
    SELECT
        SalesMonth,
        TotalSales,
        LAG(TotalSales) OVER (
            ORDER BY SalesMonth
        ) AS PreviousMonthSales
    FROM MonthlySales
)
SELECT
    SalesMonth,
    ROUND(TotalSales, 2) AS TotalSales,
    ROUND(PreviousMonthSales, 2) AS PreviousMonthSales,
    ROUND(
        (TotalSales - PreviousMonthSales)
        / NULLIF(PreviousMonthSales, 0) * 100,
        2
    ) AS MoMGrowthPct
FROM PreviousSales
ORDER BY SalesMonth;