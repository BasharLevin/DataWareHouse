
USE [master];
GO

IF DB_ID(N'RentalDW') IS NOT NULL
    DROP DATABASE [RentalDW];
GO

CREATE DATABASE [RentalDW];
GO

USE [RentalDW];
GO

CREATE TABLE dbo.DimCustomer
(
CustomerKey int IDENTITY PRIMARY KEY,
CustomerID int NOT NULL UNIQUE,
CustomerName nvarchar(100) NULL,
CustomerEmail nvarchar(100) NULL,
CustomerPhone nvarchar(50) NULL,
CustomerAddress nvarchar(100) NULL,
CustomerCity nvarchar(50) NULL,
CustomerCountry nvarchar(50) NULL
);

CREATE TABLE dbo.DimEmployee
(
EmployeeKey int IDENTITY PRIMARY KEY,
EmployeeID int NOT NULL UNIQUE,
EmployeeName nvarchar(100) NULL,
EmployeeEmail nvarchar(100) NULL,
EmployeePhone nvarchar(50) NULL,
EmployeeAddress nvarchar(50) NULL
);

CREATE TABLE dbo.DimStore
(
StoreKey int IDENTITY PRIMARY KEY,
StoreID int NOT NULL UNIQUE,
StoreName nvarchar(100) NULL,
StoreLocation nvarchar(50) NULL,
City nvarchar(50) NULL,
Country nvarchar(50) NULL,
StoreType nvarchar(50) NULL,
StoreLocationCode nvarchar(50) NULL
);

CREATE TABLE dbo.DimProduct
(
ProductKey int IDENTITY PRIMARY KEY,
ProductID int NOT NULL UNIQUE,
ProductName nvarchar(50) NULL,
ProductCategory nvarchar(50) NULL,
Manufacturer nvarchar(50) NULL,
ProductStatus nvarchar(50) NULL
);

CREATE TABLE dbo.DimService
(
ServiceKey int IDENTITY PRIMARY KEY,
ServiceID int NOT NULL UNIQUE,
ServiceType nvarchar(50) NULL,
ServiceDurationHours int NULL,
MaintenanceCost decimal(7,2) NULL
);

CREATE TABLE dbo.DimDate
(
DateKey int PRIMARY KEY,
CalendarDate date NOT NULL UNIQUE,
CalendarYear int NOT NULL,
MonthNumber int NOT NULL,
MonthName varchar(9) NOT NULL,
[Quarter] tinyint NOT NULL
);

CREATE TABLE dbo.FactRentOrder
(
RentID int NOT NULL,
LineNumber int NOT NULL,
DateKey int NOT NULL REFERENCES dbo.DimDate(DateKey),
StartDate datetime2(0) NOT NULL,
EndDateKey int NULL REFERENCES dbo.DimDate(DateKey),
EndDate datetime2(0) NULL,
CustomerKey int NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
EmployeeKey int NOT NULL REFERENCES dbo.DimEmployee(EmployeeKey),
StoreKey int NOT NULL REFERENCES dbo.DimStore(StoreKey),
ReturnStoreKey int NULL REFERENCES dbo.DimStore(StoreKey),
ProductKey int NOT NULL REFERENCES dbo.DimProduct(ProductKey),
ServiceKey int NULL REFERENCES dbo.DimService(ServiceKey),
Quantity int NULL,
UnitPrice decimal(7,2) NULL,
RentalDurationHours int NULL,
MaintenanceCost decimal (7,2) NULL,
VAT decimal(7,2) NULL,
PRIMARY KEY (RentID, LineNumber)
);

CREATE TABLE dbo.LoadRun
(
RunID int IDENTITY PRIMARY KEY,
StepName varchar(20) NOT NULL,
StartedAt datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
FinishedAt datetime2(0) NULL,
Status varchar(12) NOT NULL,
RowsInserted int NULL,
ErrorMessage nvarchar(4000) NULL
);
GO







CREATE OR ALTER PROCEDURE dbo.LoadDimensions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET LANGUAGE us_english;

    IF @@TRANCOUNT <> 0
        THROW 51003, 'Run this procedure without an open transaction.', 1;

    DECLARE @RunID int, @Rows int = 0;
    DECLARE @FirstDate date, @LastDate date;

    INSERT dbo.LoadRun (StepName, Status) 
    VALUES ('Dimensions', 'Started');

    SET @RunID = CONVERT(int, SCOPE_IDENTITY());

    BEGIN TRY
        BEGIN TRANSACTION;


        INSERT dbo.DimCustomer
            (CustomerID, CustomerName, CustomerEmail, CustomerPhone,
             CustomerAddress, CustomerCity, CustomerCountry)
        SELECT c.customer_id, c.[name], c.email, c.phone, c.[address], c.city, c.country
        FROM [RentalTestDB].dbo.Customer AS c
        WHERE c.customer_id NOT IN (SELECT CustomerID FROM dbo.DimCustomer)
        SET @Rows += @@ROWCOUNT;

        INSERT dbo.DimEmployee
            (EmployeeID, EmployeeName, EmployeeEmail, EmployeePhone, EmployeeAddress)
        SELECT e.employee_id, e.[name], e.email, e.phone, e.[address]
        FROM [RentalTestDB].dbo.Employee AS e
        WHERE e.employee_id NOT IN (SELECT EmployeeID FROM dbo.DimEmployee)
        SET @Rows += @@ROWCOUNT;

        INSERT dbo.DimStore
            (StoreID, StoreName, StoreLocation, City, Country, StoreType, StoreLocationCode)
        SELECT s.store_id, s.[name], s.[location], s.city, s.country,
               s.[type], s.location_code
        FROM [RentalTestDB].dbo.Store AS s
        WHERE s.store_id NOT IN (SELECT StoreID FROM dbo.DimStore)
        SET @Rows += @@ROWCOUNT;

        INSERT dbo.DimProduct
            (ProductID, ProductName, ProductCategory, Manufacturer,
             ProductStatus)
        SELECT i.item_id, e.[name], e.category, e.manufacturer, i.[status]
        FROM [RentalTestDB].dbo.Item AS i
        JOIN [RentalTestDB].dbo.Equipment AS e ON e.equipment_id = i.equipment_id
        WHERE i.item_id NOT IN (SELECT ProductID FROM dbo.DimProduct)
        SET @Rows += @@ROWCOUNT;

        INSERT dbo.DimService
            (ServiceID, ServiceType, ServiceDurationHours, MaintenanceCost)
        SELECT s.service_id, s.[type], s.duration, s.cost
        FROM [RentalTestDB].dbo.Service AS s
        WHERE s.service_id NOT IN (SELECT ServiceID FROM dbo.DimService)
        SET @Rows += @@ROWCOUNT;

        -- Include all start AND calculated end dates in the calendar.
        SELECT @FirstDate = MIN(d.CalendarDate), @LastDate = MAX(d.CalendarDate)
        FROM [RentalTestDB].dbo.RentOrder AS ro
        CROSS APPLY (VALUES
            (CONVERT(date, ro.startdate)),
            (CONVERT(date, DATEADD(hour, ro.RentalDurationHours, ro.startdate)))
        ) AS d(CalendarDate);

        ;WITH Calendar AS
        (
            SELECT @FirstDate AS CalendarDate
            WHERE @FirstDate IS NOT NULL
            UNION ALL
            SELECT DATEADD(day, 1, CalendarDate)
            FROM Calendar WHERE CalendarDate < @LastDate
        )
        INSERT dbo.DimDate
            (DateKey, CalendarDate, CalendarYear, MonthNumber, MonthName, [Quarter])
        SELECT CONVERT(int, CONVERT(char(8), c.CalendarDate, 112)),
               c.CalendarDate, YEAR(c.CalendarDate), MONTH(c.CalendarDate),
               DATENAME(month, c.CalendarDate), DATEPART(quarter, c.CalendarDate)
        FROM Calendar AS c
        WHERE NOT EXISTS
            (SELECT 1 FROM dbo.DimDate AS d WHERE d.CalendarDate = c.CalendarDate)
        OPTION (MAXRECURSION 0);
        SET @Rows += @@ROWCOUNT;

        UPDATE dbo.LoadRun
        SET Status = 'Completed', FinishedAt = SYSUTCDATETIME(), RowsInserted = @Rows
        WHERE RunID = @RunID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        UPDATE dbo.LoadRun
        SET Status = 'Failed', FinishedAt = SYSUTCDATETIME(),
            RowsInserted = 0, ErrorMessage = ERROR_MESSAGE()
        WHERE RunID = @RunID;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.LoadSalesOrderLines
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 51003, 'Run this procedure without an open transaction.', 1;

    DECLARE @RunID int, @Rows int;

    INSERT dbo.LoadRun (StepName, Status) VALUES ('Rental lines', 'Started');
    SET @RunID = CONVERT(int, SCOPE_IDENTITY());

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT dbo.FactRentOrder
            (RentID, LineNumber, DateKey, StartDate, EndDateKey, EndDate, CustomerKey, EmployeeKey, StoreKey, ReturnStoreKey,
             ProductKey, ServiceKey, Quantity, UnitPrice,
             RentalDurationHours, MaintenanceCost, VAT)
        SELECT rl.rentorder_id, rl.rentline_id, dd.DateKey, CONVERT(datetime2(0), ro.startdate),
               ed.DateKey, dates.EndDate, dc.CustomerKey,
               de.EmployeeKey, ds.StoreKey, rs.StoreKey, dp.ProductKey, dsvc.ServiceKey,
               rl.qty, rl.unitprice,
               ro.RentalDurationHours,
               CASE WHEN rl.maintenance_id IS NULL THEN CONVERT(decimal(7,2), 0)
                    ELSE svc.cost END, 
               rl.VAT
        FROM [RentalTestDB].dbo.RentLine AS rl
        LEFT JOIN [RentalTestDB].dbo.RentOrder AS ro 
            ON ro.rentorder_id = rl.rentorder_id
        CROSS APPLY
        (
            SELECT CONVERT(datetime2(0),
                DATEADD(hour, ro.RentalDurationHours, ro.startdate)) AS EndDate
        ) AS dates
        LEFT JOIN dbo.DimCustomer AS dc 
            ON dc.CustomerID = ro.customer_id
        LEFT JOIN dbo.DimEmployee AS de 
            ON de.EmployeeID = ro.employee_id
        LEFT JOIN dbo.DimStore AS ds 
            ON ds.StoreID = ro.store_id
        LEFT JOIN dbo.DimStore AS rs
            ON rs.StoreID = ro.return_id
        LEFT JOIN dbo.DimProduct AS dp 
            ON dp.ProductID = rl.item_id
        LEFT JOIN dbo.DimDate AS dd 
            ON dd.CalendarDate = CONVERT(date, ro.startdate)
        LEFT JOIN dbo.DimDate AS ed
            ON ed.CalendarDate = CONVERT(date, dates.EndDate)
        LEFT JOIN [RentalTestDB].dbo.Maintenance AS m
            ON m.maintenance_id = rl.maintenance_id
        LEFT JOIN [RentalTestDB].dbo.Service AS svc ON svc.service_id = m.service_id
        LEFT JOIN dbo.DimService AS dsvc ON dsvc.ServiceID = svc.service_id
        WHERE NOT EXISTS
            (SELECT 1 FROM dbo.FactRentOrder AS f
             WHERE f.RentID = rl.rentorder_id AND f.LineNumber = rl.rentline_id);
        SET @Rows = @@ROWCOUNT;

        UPDATE dbo.LoadRun
        SET Status = 'Completed', FinishedAt = SYSUTCDATETIME(), RowsInserted = @Rows
        WHERE RunID = @RunID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        UPDATE dbo.LoadRun
        SET Status = 'Failed', FinishedAt = SYSUTCDATETIME(),
            RowsInserted = 0, ErrorMessage = ERROR_MESSAGE()
        WHERE RunID = @RunID;
        THROW;
    END CATCH;
END;
GO

EXEC dbo.LoadDimensions;
EXEC dbo.LoadSalesOrderLines;


SELECT * FROM dbo.FactRentOrder ORDER BY RentID, LineNumber;

GO
