-- catalog-create.sql
--
-- @author Dekka Corp.
-- @ported from sql-ledger and combined with parts from OpenACS ecommerce package
-- @license GNU GENERAL PUBLIC LICENSE, Version 2, June 1991
-- @cvs-id
--
--

CREATE TABLE qci_parts (
  id int DEFAULT nextval ( 'id' ),
  partnumber text,
  description text,
  unit varchar(5),
  listprice float,
  sellprice float,
  lastcost float,
  priceupdate date DEFAULT current_date,
  weight float4,
  onhand float4 DEFAULT 0,
  notes text,
  makemodel bool DEFAULT 'f',
  assembly bool DEFAULT 'f',
  alternate bool DEFAULT 'f',
  rop float4,
  inventory_accno_id int,
  income_accno_id int,
  expense_accno_id int,
  bin text,
  obsolete bool DEFAULT 'f',
  bom bool DEFAULT 'f',
  image text,
  drawing text,
  microfiche text,
  partsgroup_id int,
  project_id int,
  avgcost float
);

--
CREATE TABLE qci_partsgroup (
  id int default nextval('id'),
  partsgroup text
);

create index qci_partsgroup_id_key on qci_partsgroup (id);
create unique index qci_partsgroup_key on qci_partsgroup (partsgroup);


--
CREATE TABLE qci_pricegroup (
  id int default nextval('id'),
  pricegroup text
);
--
CREATE TABLE qci_partscustomer (
  parts_id int,
  customer_id int,
  pricegroup_id int,
  pricebreak float4,
  sellprice float,
  validfrom date,
  validto date,
  curr char(3)
);

--
CREATE TABLE qci_partstax (
  parts_id int,
  chart_id int
);
--

create index qci_parts_id_key on qci_parts (id);
create index qci_parts_partnumber_key on qci_parts (lower(partnumber));
create index qci_parts_description_key on qci_parts (lower(description));
create index qci_partstax_parts_id_key on qci_partstax (parts_id);

--
create index qci_partsvendor_vendor_id_key on qci_partsvendor (vendor_id);
create index qci_partsvendor_parts_id_key on qci_partsvendor (parts_id);
--
create index qci_pricegroup_pricegroup_key on qci_pricegroup (pricegroup);
create index qci_pricegroup_id_key on qci_pricegroup (id);


