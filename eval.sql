
SELECT
    COUNT(RentID) AS NumberOfRentals,

    COUNT(DISTINCT RentID) AS UniqueRentals,

    SUM(Quantity * UnitPrice) AS TotalRentalAmount,

    SUM(RentalDurationHours) AS TotalDuration,

    SUM(MaintenanceCost) AS TotalMaintenanceCost,

    SUM(Quantity * UnitPrice)
        - SUM(MaintenanceCost) AS Profit,

    (
        SUM(Quantity * UnitPrice)
        - SUM(MaintenanceCost)
    ) * 100.0
        / NULLIF(SUM(Quantity * UnitPrice), 0)
        AS ProfitMarginPercent

FROM dbo.FactRentOrder;
