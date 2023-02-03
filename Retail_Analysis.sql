/*          Database Creation           */
    -- IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Retail_Analysis')
    -- CREATE DATABASE Retail_Analysis
--
/*          Retail Table Creation       */
    -- DROP TABLE IF EXISTS Retail;
    -- SELECT OrderID, OrderDate, O.ProductID,
    --     ProductName, ProductCategory,
    --     Quantity, Price, (Quantity * Price) Revenue,
    --     O.PropertyID, PropertyCity, PropertyState
    -- -- INTO Retail
    -- FROM OrderDetails O
    -- LEFT JOIN Products P
    -- ON o.productid = p.productid
    -- LEFT JOIN Propertyinfo I
    -- ON o.propertyid = i.propertyid;


    -- SELECT DISTINCT PropertyState, ProductCategory, SUM(Revenue) 
    -- OVER(PARTITION BY PropertyState, ProductCategory ORDER BY ProductCategory) Revenue
    -- FROM Retail
    -- WHERE ProductCategory = 'Furnishings'
    -- ORDER BY Revenue DESC
--
/*      Total Revenue and Quantity per Segment      */
    -- By Category
        SELECT COALESCE(ProductCategory,'Total') ProductCategory, SUM(Revenue) Revenue, 
        CONCAT('%',CAST((SUM(Revenue) *100.0)/(SELECT SUM(Revenue) FROM retail) AS DEC(10,2))) Rev_Percentage,
        SUM(Quantity) Quantity,
        CONCAT('%',CAST((SUM(Quantity) *100.0)/(SELECT SUM(Quantity) FROM retail) AS DEC(10,2))) Qty_Percentage,
        COUNT(OrderID) Transactions,
        CONCAT('%',CAST((COUNT(OrderID)*100.0)/(SELECT COUNT(OrderID) FROM retail) AS DEC(10,2))) Txn_Percentage
        FROM retail
        GROUP BY ProductCategory WITH ROLLUP
        ORDER BY Rev_Percentage DESC
        --OFFSET 1 ROWS 

    -- By State
        SELECT 
        COALESCE(PropertyState,'Total') PropertyState,
        SUM(Revenue) Revenue, 
        CONCAT('%', CAST((SUM(Revenue) *100.0)/(SELECT SUM(Revenue) FROM retail) AS DEC(10,2))) Rev_Percentage,
        SUM(Quantity) Quantity,
        CONCAT('%', CAST((SUM(Quantity) *100.0)/(SELECT SUM(Quantity) FROM retail) AS DEC(10,2))) Qty_Percentage,
        COUNT(OrderID) Transactions,
        CONCAT('%',CAST((COUNT(OrderID)*100.0)/(SELECT COUNT(OrderID) FROM retail) AS DEC(10,2))) Txn_Percentage
        FROM retail
        GROUP BY PropertyState WITH ROLLUP
        ORDER BY Revenue DESC
        --OFFSET 1 ROWS 

    -- By Number of Orders
        -- SELECT ProductCategory, COUNT(OrderID) Transactions,
        -- CONCAT('%',CAST((COUNT(OrderID)*100.0)/(SELECT COUNT(OrderID) FROM retail) AS DEC(10,2))) Txn_Percentage
        -- FROM retail
        -- GROUP BY ProductCategory
        -- ORDER BY Transactions DESC

    -- By Date - Month
        SELECT DATEPART(m,OrderDate) idx, DATENAME(m,OrderDate) AS Month, 
        SUM(Revenue) Revenue,
        CONCAT('%',CAST((SUM(Revenue)*100.0)/(SELECT SUM(Revenue) FROM retail) AS DEC(10,2))) Rev_Percentage,
        SUM(Quantity) Quantity,
        CONCAT('%',CAST((SUM(Quantity)*100.0)/(SELECT SUM(Quantity) FROM retail) AS DEC(10,2))) Qty_Percentage,
        COUNT(OrderID) Transactions,
        CONCAT('%',CAST((COUNT(OrderID)*100.0)/(SELECT COUNT(OrderID) FROM retail) AS DEC(10,2))) Txn_Percentage
        FROM retail
        -- WHERE DATEPART(yy,OrderDate) = '@year'
        GROUP BY DATEPART(m,OrderDate), DATENAME(m,OrderDate)
        ORDER BY DATEPART(m,OrderDate);
--
/*      Avg. Revenue per Segment                    */
    -- Shows which segment ordered higher quantities of the product
    -- By Product Category
        SELECT DISTINCT ProductCategory,
        CAST(AVG(Revenue * 1.0) OVER(PARTITION BY ProductCategory) AS DEC(10,2)) AvgRevenue
        FROM Retail
        ORDER BY AvgRevenue DESC

    -- By State
        SELECT DISTINCT PropertyState,
        CAST(AVG(Revenue * 1.0) OVER(PARTITION BY PropertyState) AS DEC(10,2)) AvgRevenue
        FROM Retail
        ORDER BY AvgRevenue DESC
    
    -- By State and Product Category
        SELECT PropertyState State, ProductCategory, 
        CAST(AVG(Revenue * 1.0) AS DEC(10,2)) AvgRevenue,
        COUNT(OrderID) Orders
        FROM retail
        GROUP BY PropertyState, ProductCategory
        ORDER BY State
--
/*      Revenue Growth between 2015 and 2016        */
    -- Using Window Functions
        -- CREATE OR ALTER VIEW Growth AS
        -- (SELECT DISTINCT(ProductCategory) ProductCategory, Revenue [2015],
        --  LEAD(REVENUE,1) OVER(PARTITION BY ProductCategory ORDER BY year ASC) [2016]
        --  FROM (SELECT DISTINCT ProductCategory, DATEPART(yy,OrderDate) Year, 
        --        SUM(Revenue) OVER(PARTITION BY ProductCategory, DATEPART(yy,OrderDate)) Revenue
        --        FROM retail) q)

        SELECT *, CONCAT('%',CAST((([2016]-[2015]) *100.0)/[2015] AS DEC(10,2))) Revenue_Growth
        FROM Growth
        WHERE [2016] IS NOT NULL;

    -- Using Pivot function 
        WITH Pivot_CTE AS
         (SELECT *
          FROM
              (SELECT DISTINCT ProductCategory, DATEPART(yy,OrderDate) Year, 
              SUM(Revenue) OVER(PARTITION BY ProductCategory, DATEPART(yy,OrderDate)) Revenue
              FROM retail) q
          PIVOT(                            -- Pivot statement
            SUM(Revenue)                    -- Aggregate column values
            for year in ([2015], [2016])    -- New columns
          ) AS p)
        --
        SELECT *, CONCAT('%',CAST((([2016]-[2015]) *100.0)/[2015] AS DEC(10,2))) Revenue_Growth
        FROM Pivot_CTE

--
/*      Order Growth between 2015 and 2016          */
    -- Using Case Statements
        SELECT ProductCategory, SUM([2015]) [2015], SUM([2016]) [2016], 
        CONCAT('%',CAST((SUM([2016])-SUM([2015]))*100.0/SUM([2015]) AS DEC(10,2))) Order_Growth
        FROM
            (SELECT DISTINCT ProductCategory, 
            CASE WHEN DATEPART(yy, OrderDate) = '2015' THEN COUNT(OrderID) ELSE 0 END AS [2015],
            CASE WHEN DATEPART(yy, OrderDate) = '2016' THEN COUNT(OrderID) ELSE 0 END AS [2016]
            FROM retail
            GROUP BY ProductCategory, DATEPART(yy, OrderDate)) q
        GROUP BY ProductCategory

    -- Using correlated subqueries
        SELECT *, CONCAT('%',CAST((([2016]-[2015]) *100.0)/[2015] AS DEC(10,2))) Order_Growth
        FROM
            (SELECT DISTINCT ProductCategory, 
            (SELECT COUNT(OrderID) FROM retail r1 WHERE DATEPART(yy,OrderDate) = '2015' AND r. ProductCategory = r1.ProductCategory) [2015],
            (SELECT COUNT(OrderID) FROM retail r1 WHERE DATEPART(yy,OrderDate) = '2016' AND r. ProductCategory = r1.ProductCategory) [2016]
            FROM retail r) q
--
/*      Top n Products per Product Category         */
    -- Top Products per Category
        SELECT DISTINCT ProductCategory,
        FIRST_VALUE(Revenue) OVER(PARTITION BY ProductCategory ORDER BY Revenue DESC) Revenue,
        FIRST_VALUE(ProductName) OVER(PARTITION BY ProductCategory ORDER BY Revenue DESC) Top_Product
        FROM
            (SELECT DISTINCT ProductCategory, ProductName, 
            SUM(Revenue) OVER(PARTITION BY ProductCategory, ProductName) Revenue,
            SUM(Quantity) OVER(PARTITION BY ProductCategory, ProductName) Quantity,
            COUNT(OrderID) OVER(PARTITION BY ProductCategory, ProductName) Transactions
            FROM retail)q

    -- Top 3 Products per Category
        SELECT *
        FROM
            (SELECT ProductCategory, ProductName, SUM(Revenue) Revenue,
            SUM(Quantity) Quantity, COUNT(OrderID) Transactions,
            DENSE_RANK() OVER(PARTITION BY ProductCategory ORDER BY SUM(Revenue) DESC) Rank
            FROM retail
            GROUP BY ProductCategory, ProductName --WITH ROLLUP
            ) Q
        WHERE Rank <= 3

    -- Top Products per State
        SELECT *--State, STRING_AGG(ProductName,',') Products
        FROM
        (SELECT PropertyState State, ProductName, SUM(Revenue) Revenue, COUNT(OrderID) Orders, SUM(Quantity) Quantity,
        DENSE_RANK() OVER(PARTITION BY PropertyState ORDER BY SUM(REVENUE) DESC) Rank
        FROM retail
        GROUP BY PropertyState, ProductName) q
        WHERE Rank <=3
        -- GROUP BY State
        ORDER BY State, Revenue DESC

    -- Product Penetration
        SELECT DISTINCT ProductCategory, ProductName, 
        CONCAT('%',CAST (COUNT(OrderID) OVER (PARTITION BY ProductCategory, ProductName) * 100.0/
        COUNT(OrderID) OVER (PARTITION BY ProductCategory) AS DEC(10,2))) Order_Percentage
        FROM retail
        ORDER BY ProductCategory, Order_Percentage DESC;
--
/*      Stored Procedures                           */
    -- Average Revenue per Segment
        CREATE OR ALTER PROCEDURE sp_Avg_Revenue (@segment nvarchar(15))
        AS
        BEGIN
            DECLARE @sql NVARCHAR(600); 
            SET @sql = 'SELECT DISTINCT ' + @segment +', 
            CAST(AVG(Revenue * 1.0) OVER(PARTITION BY ' + @segment + ' ) AS DEC(10,2)) AvgRevenue,
            COUNT(OrderID) OVER(PARTITION BY ' + @segment + ' ) Orders 
            FROM retail ORDER BY AvgRevenue DESC'
            EXEC sp_executesql @sql
        END
        GO

        EXEC SP_Avg_Revenue 'PropertyState'
        GO
    -- Revenue per Order with Percentage Split
        CREATE OR ALTER PROCEDURE sp_Percentage_split @segment NVARCHAR(15)
        AS
        BEGIN
            DECLARE @sql NVARCHAR(1000)
            SET @sql = 'SELECT COALESCE( ' + @segment + ', ' + quotename('Total','''') + ') Segment, SUM(Revenue) Revenue, 
                        CONCAT( ' + quotename('%','''') + ' , CAST((SUM(Revenue) *100.0)/(SELECT SUM(Revenue) FROM retail) AS DEC(10,2))) Revenue_Percentage,
                        SUM(Quantity) Quantity,
                        CONCAT( ' + quotename('%','''') + ' , CAST((SUM(Quantity) *100.0)/(SELECT SUM(Quantity) FROM retail) AS DEC(10,2))) Quantity_Percentage,
                        COUNT(OrderID) Transactions,
                        CONCAT( ' + quotename('%','''') + ' , CAST((COUNT(OrderID)*100.0)/(SELECT COUNT(OrderID) FROM retail) AS DEC(10,2))) Txn_Percentage
                        FROM retail
                        GROUP BY ' + @segment +  
                        ' ORDER BY Revenue_Percentage DESC'
            EXEC sp_executesql @sql
        END
        GO

        EXEC sp_Percentage_split 'PropertyState'

    -- Order growth between 2015 and 2016
        CREATE OR ALTER PROCEDURE sp_Order_Growth @segment NVARCHAR(15)
        AS 
        BEGIN
            DECLARE @sql NVARCHAR(1000)
            SET @sql =  'SELECT *, CONCAT( ' + quotename('%','''') + ' ,
                        CAST((([2016]-[2015]) *100.0)/[2015] AS DEC(10,2))) Order_Growth FROM
                        (SELECT DISTINCT ' + @segment + ', 
                        (SELECT COUNT(OrderID) FROM retail r1 WHERE DATEPART(yy,OrderDate) = ' 
                         + quotename('2015','''') + ' AND r.' + @segment + ' = r1.' + @segment + ' ) [2015],
                        (SELECT COUNT(OrderID) FROM retail r1 WHERE DATEPART(yy,OrderDate) = ' 
                         + quotename('2016','''') + ' AND r.' + @segment + ' = r1.' + @segment + ' ) [2016]
                        FROM retail r) q'
            EXEC sp_executesql @sql
        END
        GO

        EXEC sp_Order_Growth 'PropertyState'
        GO
  
    -- Revenue growth between 2015 and 2016
        CREATE OR ALTER PROCEDURE sp_Revenue_Growth @segment NVARCHAR(15)
        AS 
        BEGIN
            DECLARE @sql NVARCHAR(1000)
            SET @sql =  'SELECT *, CONCAT( ' + quotename('%','''') + ' ,
                        CAST((([2016]-[2015]) *100.0)/[2015] AS DEC(10,2))) Revenue_Growth FROM
                        (SELECT DISTINCT ' + @segment + ', 
                        (SELECT SUM(Revenue) FROM retail r1 WHERE DATEPART(yy,OrderDate) = ' 
                         + quotename('2015','''') + ' AND r.' + @segment + ' = r1.' + @segment + ' ) [2015],
                        (SELECT SUM(Revenue) FROM retail r1 WHERE DATEPART(yy,OrderDate) = ' 
                         + quotename('2016','''') + ' AND r.' + @segment + ' = r1.' + @segment + ' ) [2016]
                        FROM retail r) q'
            EXEC sp_executesql @sql
        END
        GO

        EXEC sp_Revenue_Growth 'ProductCategory'
        GO