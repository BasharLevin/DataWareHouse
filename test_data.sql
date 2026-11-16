USE [master];
GO


-- Dynamic execution keeps database creation outside a user transaction.
-- An existing database is never reused or overwritten.
IF OBJECT_ID(N'tempdb..#RentalTestCreated') IS NOT NULL
    DROP TABLE #RentalTestCreated;

IF DB_ID(N'RentalTestDB') IS NOT NULL
    THROW 51200, 'RentalTestDB already exists. Choose a different test database name.', 1;
ELSE
BEGIN
    EXEC (N'CREATE DATABASE [RentalTestDB];');
    CREATE TABLE #RentalTestCreated (Created bit NOT NULL);
END;
GO

USE [RentalTestDB];
GO

-- If SSMS continues after an earlier batch error, this guard prevents writing
-- into an existing test database. The entire schema/data build is one transaction.
IF OBJECT_ID(N'tempdb..#RentalTestCreated') IS NULL
    THROW 51204, 'Database creation did not succeed in this run. No data was inserted.', 1;

IF EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped = 0)
    THROW 51201, 'The test database is not empty. No tables or data were changed.', 1;

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE dbo.Customer
    (
        customer_id int NOT NULL PRIMARY KEY,
        [name] nvarchar(100) NOT NULL,
        email nvarchar(100) NULL,
        phone nvarchar(50) NULL,
        [address] nvarchar(100) NULL,
        city nvarchar(50) NULL,
        country nvarchar(50) NULL
    );

    CREATE TABLE dbo.Store
    (
        store_id int NOT NULL PRIMARY KEY,
        [name] nvarchar(100) NOT NULL,
        [location] nvarchar(50) NULL,
        location_code nvarchar(50) NULL,
        [type] nvarchar(50) NULL,
        employee_id int NULL,
        city nvarchar(50) NULL,
        country nvarchar(50) NULL
    );

    CREATE TABLE dbo.Employee
    (
        employee_id int NOT NULL PRIMARY KEY,
        store_id int NOT NULL REFERENCES dbo.Store(store_id),
        [name] nvarchar(100) NOT NULL,
        [role] nvarchar(50) NULL,
        email nvarchar(100) NULL,
        phone nvarchar(50) NULL,
        [address] nvarchar(50) NULL
    );

    ALTER TABLE dbo.Store ADD CONSTRAINT FK_Store_Employee
        FOREIGN KEY (employee_id) REFERENCES dbo.Employee(employee_id);

    CREATE TABLE dbo.Equipment
    (
        equipment_id int NOT NULL PRIMARY KEY,
        [name] nvarchar(50) NOT NULL,
        category nvarchar(50) NULL,
        manufacturer nvarchar(50) NULL
    );

    CREATE TABLE dbo.Item
    (
        item_id int NOT NULL PRIMARY KEY,
        store_id int NOT NULL REFERENCES dbo.Store(store_id),
        [status] nvarchar(10) NOT NULL,
        equipment_id int NOT NULL REFERENCES dbo.Equipment(equipment_id)
    );

    CREATE TABLE dbo.Service
    (
        service_id int NOT NULL PRIMARY KEY,
        [type] nvarchar(50) NOT NULL,
        duration int NOT NULL CHECK (duration >= 0),
        cost decimal(7,2) NOT NULL CHECK (cost >= 0)
    );

    CREATE TABLE dbo.ServiceActivity
    (
        activity_id int NOT NULL PRIMARY KEY,
        service_id int NOT NULL REFERENCES dbo.Service(service_id),
        [name] nvarchar(100) NOT NULL,
        duration_hours int NOT NULL CHECK (duration_hours >= 0),
        cost decimal(7,2) NOT NULL CHECK (cost >= 0)
    );

    CREATE TABLE dbo.Maintenance
    (
        maintenance_id int NOT NULL PRIMARY KEY,
        service_id int NOT NULL REFERENCES dbo.Service(service_id),
        item_id int NOT NULL REFERENCES dbo.Item(item_id),
        CONSTRAINT UQ_Maintenance_RecordItem UNIQUE (maintenance_id, item_id)
    );

    CREATE TABLE dbo.RentOrder
    (
        rentorder_id int NOT NULL PRIMARY KEY,
        customer_id int NOT NULL REFERENCES dbo.Customer(customer_id),
        store_id int NOT NULL REFERENCES dbo.Store(store_id),
        employee_id int NOT NULL REFERENCES dbo.Employee(employee_id),
        startdate datetime2(0) NOT NULL,
        enddate datetime2(0) NULL,
        price decimal(7,2) NOT NULL CHECK (price >= 0),
        return_id int NULL REFERENCES dbo.Store(store_id),
        CONSTRAINT CK_RentOrder_Dates CHECK (enddate IS NULL OR enddate >= startdate)
    );

    CREATE TABLE dbo.RentLine
    (
        rentline_id int NOT NULL,
        rentorder_id int NOT NULL REFERENCES dbo.RentOrder(rentorder_id),
        qty int NOT NULL CHECK (qty > 0),
        unit int NOT NULL DEFAULT 1,
        unitprice decimal(7,2) NOT NULL CHECK (unitprice >= 0),
        VAT decimal(7,2) NOT NULL,
        item_id int NOT NULL REFERENCES dbo.Item(item_id),
        maintenance_id int NULL,
        PRIMARY KEY (rentorder_id, rentline_id),
        -- A nullable single link gives each line zero or one service.
        -- Composite FK also guarantees that maintenance concerns the rented item.
        CONSTRAINT FK_RentLine_MaintenanceItem
            FOREIGN KEY (maintenance_id, item_id)
            REFERENCES dbo.Maintenance(maintenance_id, item_id)
    );

    INSERT dbo.Customer
        (customer_id, [name], email, phone, [address], city, country)
    VALUES
        (1, N'Anna Test', N'anna@example.com', N'5550101', N'1 Sample Road', N'Helsinki', N'Finland'),
        (2, N'Ben Test', N'ben@example.com', N'5550102', N'2 Sample Road', N'Tampere', N'Finland'),
        (3, N'Cara Test', N'cara@example.com', N'5550103', N'3 Sample Road', N'Helsinki', N'Finland');

    INSERT dbo.Store
        (store_id, [name], [location], location_code, [type], employee_id, city, country)
    VALUES
        (1, N'Central Rentals', N'10 Market Road', N'HEL01', N'Shop', NULL, N'Helsinki', N'Finland'),
        (2, N'North Rentals', N'20 Market Road', N'TAM01', N'Shop', NULL, N'Tampere', N'Finland');

    INSERT dbo.Employee
        (employee_id, store_id, [name], [role], email, phone, [address])
    VALUES
        (1, 1, N'Ella Test', N'Manager', N'ella@example.com', N'5550201', N'1 Staff Road'),
        (2, 1, N'Finn Test', N'Agent', N'finn@example.com', N'5550202', N'2 Staff Road'),
        (3, 2, N'Grace Test', N'Manager', N'grace@example.com', N'5550203', N'3 Staff Road');

    UPDATE dbo.Store SET employee_id = 1 WHERE store_id = 1;
    UPDATE dbo.Store SET employee_id = 3 WHERE store_id = 2;

    INSERT dbo.Equipment (equipment_id, [name], category, manufacturer)
    VALUES
        (1, N'Drill', N'Tools', N'Sample Tools'),
        (2, N'Carpet Cleaner', N'Cleaning', N'Sample Clean'),
        (3, N'Tent', N'Outdoor', N'Sample Outdoor');

    INSERT dbo.Item (item_id, store_id, [status], equipment_id)
    VALUES (1, 1, N'Ready', 1), (2, 1, N'Ready', 1),
           (3, 2, N'Ready', 2), (4, 1, N'Ready', 3);

    INSERT dbo.Service (service_id, [type], duration, cost)
    VALUES (1, N'Basic Care', 0, 0), (2, N'Full Care', 0, 0);

    INSERT dbo.ServiceActivity (activity_id, service_id, [name], duration_hours, cost)
    VALUES
        (1, 1, N'Inspection', 1, 5.00),
        (2, 1, N'Cleaning', 1, 10.00),
        (3, 2, N'Inspection', 1, 5.00),
        (4, 2, N'Adjustment', 2, 20.00);

    -- Store service-level totals; the ETL never joins activities to rental lines.
    UPDATE s SET duration = a.TotalHours, cost = a.TotalCost
    FROM dbo.Service AS s
    JOIN
    (
        SELECT service_id, SUM(duration_hours) AS TotalHours, SUM(cost) AS TotalCost
        FROM dbo.ServiceActivity GROUP BY service_id
    ) AS a ON a.service_id = s.service_id;

    INSERT dbo.Maintenance (maintenance_id, service_id, item_id)
    VALUES (1, 1, 1), (2, 2, 3);

    INSERT dbo.RentOrder
        (rentorder_id, customer_id, store_id, employee_id, startdate, enddate, price, return_id)
    VALUES
        (1, 1, 1, 1, '2025-01-10T09:00:00', '2025-01-11T09:00:00', 70.00, 1),
        (2, 2, 2, 3, '2025-02-05T10:00:00', '2025-02-07T10:00:00', 60.00, 1),
        (3, 3, 1, 2, '2025-03-15T12:00:00', '2025-03-16T12:00:00', 35.00, 1);

    INSERT dbo.RentLine
        (rentline_id, rentorder_id, qty, unit, unitprice, VAT, item_id, maintenance_id)
    VALUES
        (1, 1, 1, 1, 30.00, 0.20, 1, 1),
        (2, 1, 1, 1, 40.00, 0.20, 4, NULL),
        (1, 2, 1, 1, 60.00, 0.20, 3, 2),
        (1, 3, 1, 1, 20.00, 0.20, 2, NULL),
        (2, 3, 1, 1, 15.00, 0.20, 1, NULL);

    -- Verify the complete sample before committing it.
    IF (SELECT COUNT(*) FROM dbo.RentLine) <> 5
       OR (SELECT SUM(qty * unitprice) FROM dbo.RentLine) <> 165.00
        THROW 51202, 'Sample rental totals do not match expected values.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.RentOrder AS ro
        JOIN dbo.Employee AS e ON e.employee_id = ro.employee_id
        WHERE e.store_id <> ro.store_id
    )
        THROW 51203, 'An employee is assigned to the wrong rental-origin store.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'RentalTestDB created successfully' AS Result;

SELECT ro.rentorder_id, rl.rentline_id, ro.store_id AS RentalStoreID,
       ro.return_id AS ReturnStoreID, ro.employee_id, rl.item_id,
       m.service_id, rl.qty, rl.unitprice,
       rl.qty * rl.unitprice AS RentalAmount,
       COALESCE(s.cost, 0) AS MaintenanceCost
FROM dbo.RentLine AS rl
JOIN dbo.RentOrder AS ro ON ro.rentorder_id = rl.rentorder_id
LEFT JOIN dbo.Maintenance AS m ON m.maintenance_id = rl.maintenance_id
LEFT JOIN dbo.Service AS s ON s.service_id = m.service_id
ORDER BY ro.rentorder_id, rl.rentline_id;

DROP TABLE #RentalTestCreated;
GO
