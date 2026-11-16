use rental_dw;
go

if col_length('dbo.factrentorder', 'returnstorekey') is null
begin
    alter table dbo.factrentorder
    add returnstorekey int null;
end;
go

if not exists
(
    select 1
    from sys.foreign_keys
    where name = 'fk_factrentorder_returnstore'
      and parent_object_id = object_id('dbo.factrentorder')
)
begin
    alter table dbo.factrentorder
    add constraint fk_factrentorder_returnstore
    foreign key (returnstorekey)
    references dbo.dimstore(storekey);
end;
go

update f
set f.returnstorekey = ds.storekey
from dbo.factrentorder as f
inner join rentaltestdb.dbo.rentorder as ro
    on ro.rentorder_id = f.rentid
left join dbo.dimstore as ds
    on ds.storeid = ro.return_id;
go

select top 20
    f.rentid,
    f.linenumber,
    s.storename as rentalstore,
    rs.storename as returnstore,
    f.rentalamount
from dbo.factrentorder as f
inner join dbo.dimstore as s
    on s.storekey = f.storekey
left join dbo.dimstore as rs
    on rs.storekey = f.returnstorekey
order by f.rentid, f.linenumber;




USE Rental_DW;
GO

ALTER TABLE dbo.FactRentOrder
ADD EndDateKey INT NULL;
GO

alter table dbo.factrentorder
add constraint fk_factrentorder_enddate
foreign key (enddatekey)
references dbo.dimdate(datekey);
go

update f
set f.enddatekey = d.datekey
from dbo.factrentorder as f
join rentaltestdb.dbo.rentorder as ro
    on ro.rentorder_id = f.rentid
left join dbo.dimdate as d
    on d.calendardate = cast(ro.enddate as date);

select * from factrentorder;
