Synthetic rental data for RentalTestDB (SQL Server)

CSV files contain the complete replacement dataset, including the exact 3 example RentOrder rows and 5 example RentLine rows supplied by the user. Import into an EMPTY operational database with the supplied schema, not as additional rows on top of the example records.

Import order: Customer, Store (employee_id must initially be NULL), Employee, then update Store.employee_id from the Store.csv values; Equipment, Item, Service, ServiceActivity, Maintenance, RentOrder, RentLine. The circular Store.employee_id -> Employee relationship requires the two-pass Store import.

For direct SQL Server import, use staging tables or an import wizard; UTF-8 with BOM, comma-separated, headers, empty fields mean SQL NULL. SQL Server's CSV import wizard may require explicit date and numeric column types.

RentLine.unit: 1=day, 2=hour, 3=week. RentLine.qty = number of billing units. For example qty=3, unit=1, unitprice=40 -> rental amount 120. VAT stored as a decimal fraction (0.25 = 25%), except the 5 preserved sample lines have 0.20. RentOrder.price = sum of qty*unitprice across its lines (excludes maintenance charges and VAT). Maintenance is linked to a rental line only when the maintenance record's item_id matches that rental line's item_id.

Data are entirely synthetic. All emails use example.com; names/addresses are fabricated.

Counts:
Customer: 10,000
Store: 50
Employee: 250
Equipment: 200
Item: 5,000
Service: 20
ServiceActivity: 58
Maintenance: 2,000
RentOrder: 50,000
RentLine: 81,671
