-- inventory-control-create.sql
--
-- @author Dekka Corp.
-- @ported from sql-ledger and combined with parts from OpenACS ecommerce package
-- @license GNU GENERAL PUBLIC LICENSE, Version 2, June 1991
-- @cvs-id
--

-- following from SL

CREATE TABLE qci_makemodel (
  parts_id integer,
  make text,
  model text
);

create index qci_makemodel_parts_id_key on qci_makemodel (parts_id);
create index qci_makemodel_make_key on qci_makemodel (lower(make));
create index qci_makemodel_model_key on qci_makemodel (lower(model));


CREATE TABLE qci_warehouse (
  id int default nextval('id'),
  description text
);


CREATE TABLE qci_inventory (
  warehouse_id int,
  parts_id int,
  trans_id int,
  orderitems_id int,
  qty float4,
  shippingdate date,
  employee_id int
);


CREATE FUNCTION qci_check_inventory() RETURNS OPAQUE AS '

declare
  itemid int;
  row_data inventory%rowtype;

begin

  if not old.quotation then
    for row_data in select * from qci_inventory where trans_id = old.id loop
      select into itemid id from orderitems where trans_id = old.id and id = row_data.orderitems_id;

      if itemid is null then
	delete from qci_inventory where trans_id = old.id and orderitems_id = row_data.orderitems_id;
      end if;
    end loop;
  end if;
return old;
end;
' language 'plpgsql';
-- end function





--  following from ecommerce package

-- Helper stuff (ben@adida.net)
-- gilbertw - I pulled this from OpenACS 3.2.5
-- there are a few calls to the Oracle least function
create function qci_least(numeric,numeric)
returns numeric
as '
DECLARE
        first alias for $1;
        second alias for $2;
BEGIN
        if first < second
        then return first;
        else return second;
        end if;
END;
' language 'plpgsql';

-- gilbertw
-- timespan_days taken from OpenACS 3.2.5
-- can't cast numeric to varchar/text so I made the input varchar
create function qci_timespan_days(float) returns interval as '
DECLARE
        n_days alias for $1;
BEGIN
        return (n_days::text || '' days'')::interval;
END;
' language 'plpgsql';


-- this should be replaced by the object_id sequence
-- grep for it in files...
-- create sequence ec_product_id_sequence start 1;

-- This table contains the products and also the product series.
-- A product series has the same fields as a product (it actually
-- *is* a product, since it's for sale, has its own price, etc.).
-- The only difference is that it has other products associated
-- with it (that are part of it).  So information about the
-- whole series is kept in this table and the product_series_map
-- table below keeps track of which products are inside each
-- series. 

-- wtem@olywa.net, 2001-03-24
-- begin  
--        acs_object_type__create_type ( 
--              supertype     => 'acs_object', 
--              object_type   => 'ec_product', 
--              pretty_name   => 'Product', 
--              pretty_plural => 'Products', 
--              table_name    => 'EC_PRODUCTS', 
--              id_column     => 'PRODUCT_ID',
-- 	     package_name  => 'ECOMMERCE'
--        ); 
-- end;
-- /
-- show errors;

create function inline_0 ()
returns integer as '
begin

  PERFORM acs_object_type__create_type (
    ''ec_product'',
    ''Product'',
    ''Products'',
    ''acs_object'',
    ''ec_products'',
    ''product_id'',
    ''ecommerce'',
    ''f'',
    null,
    null
   );

  return 0;

end;' language 'plpgsql';

select inline_0 ();
drop function inline_0 ();

-- wtem@olywa.net, 2001-03-24
-- we aren't going to bother to define all the attributes of an ec_product type
-- for now, because we are just using it for site-wide-search anyway
-- we have a corresponding pl/sql package for the ec_product object_type
-- it can be found at ecommerce/sql/ec-product-package-create.sql
-- and is called at the end of this script
create table qci_ec_products (
        product_id              integer constraint qci_ec_products_product_id_fk
				references acs_objects(object_id)
				on delete cascade
				constraint qci_ec_products_product_id_pk
				primary key,
	-- above changed by wtem@olywa.net, 2001-03-24
	                        -- integer not null primary key,
        sku                     varchar(100),
        product_name            varchar(200),
        creation_date           timestamptz default current_timestamp not null,
        one_line_description    varchar(400),
        detailed_description    varchar(4000),
        search_keywords         varchar(4000),
        -- this is the regular price for the product.  If user
        -- classes are charged a different price, it should be
        -- specified in qci_ec_product_user_class_prices
        price                   numeric, 
        -- for stuff that can't be shipped like services
        no_shipping_avail_p     boolean default 'f',
        -- leave this blank if shipping is calculated using
        -- one of the more complicated methods available
        shipping                numeric,
        -- fill this in if shipping is calculated by: above price
        -- for first item (with this product_id), and the below
        -- price for additional items (with this product_id)
        shipping_additional     numeric,
        -- fill this in if shipping is calculated using weight
        -- use whatever units you want (lbs/kg), just be consistent
        -- and make your shipping algorithm take the units into
        -- account
        weight                  numeric,
        -- holds pictures, sample chapters, etc.
	dirname                 varchar(200),
        -- whether this item should show up in searches (e.g., if it's
        -- a volume of a series, you might not want it to)
        present_p               boolean default 't',
        -- whether the item should show up at all in the user pages
        active_p                boolean default 't',
        -- the date the product becomes available for sale (it can be listed
        -- before then, it's just not buyable)
	available_date          timestamptz default current_timestamp not null,
        announcements           varchar(4000),
        announcements_expire    timestamptz,
        -- if there's a web site with more info about the product
        url                     varchar(300),
        template_id             integer references ecca_ec_templates,
        -- o = out of stock, q = ships quickly, m = ships
        -- moderately quickly, s = ships slowly, i = in stock
        -- with no message about the speed of the shipment (shipping
        -- messages are in parameters .ini file)
        stock_status            char(1) check (stock_status in ('o','q','m','s','i')),
        -- comma-separated lists of available colors, sizes, and styles for the user
        -- to choose upon ordering
        color_list              varchar(4000),
        size_list               varchar(4000),
        style_list              varchar(4000),
        -- email this list on purchase
        email_on_purchase_list  varchar(4000),
        -- the user ID and IP address of the creator of the product
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null    
);

create view qci_ec_products_displayable
as
select * from qci_ec_products
where active_p='t';

create view qci_ec_products_searchable
as
select * from qci_ec_products
where active_p='t' and present_p='t';

create table qci_ec_products_audit (
        product_id              integer,
        product_name            varchar(200),
        creation_date           timestamptz,
        one_line_description    varchar(400),
        detailed_description    varchar(4000),
        search_keywords         varchar(4000),
        price                   numeric,
        shipping                numeric,
        shipping_additional     numeric,
        weight                  numeric,
        dirname                 varchar(200),
        present_p               boolean default 't',
        active_p                boolean default 't',
        available_date          timestamptz,
        announcements           varchar(4000),
        announcements_expire    timestamptz,
        url                     varchar(300),
        template_id             integer,
        stock_status            char(1) check (stock_status in ('o','q','m','s','i')),
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);

create function qci_ec_products_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_products_audit (
        product_id, product_name, creation_date,
        one_line_description, detailed_description,
        search_keywords, shipping,
        shipping_additional, weight,
        dirname, present_p,
        active_p, available_date,
        announcements, announcements_expire, 
        url, template_id,
        stock_status,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.product_id, old.product_name, old.creation_date,
        old.one_line_description, old.detailed_description,
        old.search_keywords, old.shipping,
        old.shipping_additional, old.weight,
        old.dirname, old.present_p,
        old.active_p, old.available_date,
        old.announcements, old.announcements_expire, 
        old.url, old.template_id,
        old.stock_status,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_products_audit_tr
after update or delete on qci_ec_products
for each row execute procedure qci_ec_products_audit_tr ();


-- people who bought product_id also bought products 0 through
-- 4, where product_0 is the most frequently purchased, 1 is next,
-- etc.
create table qci_ec_product_purchase_comb (
        product_id      integer not null primary key references qci_ec_products,
        product_0       integer references qci_ec_products,
        product_1       integer references qci_ec_products,
        product_2       integer references qci_ec_products,
        product_3       integer references qci_ec_products,
        product_4       integer references qci_ec_products
);

create index qci_ec_product_purchase_comb_idx0 on qci_ec_product_purchase_comb(product_0);
create index qci_ec_product_purchase_comb_idx1 on qci_ec_product_purchase_comb(product_1);
create index qci_ec_product_purchase_comb_idx2 on qci_ec_product_purchase_comb(product_2);
create index qci_ec_product_purchase_comb_idx3 on qci_ec_product_purchase_comb(product_3);
create index qci_ec_product_purchase_comb_idx4 on qci_ec_product_purchase_comb(product_4);

create sequence qci_ec_sale_price_id_seq start 1;
create view qci_ec_sale_price_id_sequence as select nextval('qci_ec_sale_price_id_seq') as nextval;

create table qci_ec_sale_prices (
        sale_price_id           integer not null primary key,
        product_id              integer not null references qci_ec_products,
        sale_price              numeric,
        sale_begins             timestamptz not null,
        sale_ends               timestamptz not null,
        -- like Introductory Price or Sale Price or Special Offer
        sale_name               varchar(30),
        -- if non-null, the user has to know this code to get the sale price
        offer_code              varchar(20),
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null
);

create index qci_ec_sale_prices_by_product_idx on qci_ec_sale_prices(product_id);

create view qci_ec_sale_prices_current
as
select * from qci_ec_sale_prices
where now() >= sale_begins
and now() <= sale_ends;


create table qci_ec_sale_prices_audit (
        sale_price_id           integer,
        product_id              integer,
        sale_price              numeric,
        sale_begins             timestamptz,
        sale_ends               timestamptz,
        sale_name               varchar(30),
        offer_code              varchar(20),
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);


create function qci_ec_sale_prices_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_sale_prices_audit (
        sale_price_id, product_id, sale_price,
        sale_begins, sale_ends, sale_name, offer_code,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.sale_price_id, old.product_id, old.sale_price,
        old.sale_begins, old.sale_ends, old.sale_name, old.offer_code,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_sale_prices_audit_tr
after update or delete on qci_ec_sale_prices
for each row execute procedure qci_ec_sale_prices_audit_tr ();


create table qci_ec_product_series_map (
        -- this is the product_id of a product that happens to be
        -- a series
        series_id               integer not null references qci_ec_products,
        -- this is the product_id of a product that is one of the
        -- components of the above series
        component_id            integer not null references qci_ec_products,
        primary key (series_id, component_id),
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null
);

create index qci_ec_product_series_map_idx2 on qci_ec_product_series_map(component_id);

create table qci_ec_product_series_map_audit (
        series_id               integer,
        component_id            integer,
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);


create function qci_ec_product_series_map_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_product_series_map_audit (
        series_id, component_id,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.series_id, old.component_id,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address      
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_product_series_map_audit_tr
after update or delete on qci_ec_product_series_map
for each row execute procedure qci_ec_product_series_map_audit_tr ();





-- this specifies that product_a links to product_b on the display page for product_a
create table qci_ec_product_links (
        product_a               integer not null references qci_ec_products,
        product_b               integer not null references qci_ec_products,
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null,
        primary key (product_a, product_b)
);

create index qci_ec_product_links_idx on qci_ec_product_links (product_b);

create table qci_ec_product_links_audit (
        product_a               integer,
        product_b               integer,
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);

create function qci_ec_product_links_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_product_links_audit (
        product_a, product_b,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.product_a, old.product_b,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address      
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_product_links_audit_tr
after update or delete on qci_ec_product_links
for each row execute procedure qci_ec_product_links_audit_tr ();


-- comments made by users on the products
create table qci_ec_product_comments (
        comment_id              integer not null primary key,
        product_id              integer not null references qci_ec_products,
        user_id                 integer not null references users,
        user_comment            varchar(4000),
        one_line_summary        varchar(300),
        rating                  numeric,
        -- in some systems, the administrator will have to approve comments first
        approved_p              boolean,
        comment_date            timestamptz,
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null
);

create index qci_ec_product_comments_idx on qci_ec_product_comments(product_id);
create index qci_ec_product_comments_idx2 on qci_ec_product_comments(user_id);
create index qci_ec_product_comments_idx3 on qci_ec_product_comments(approved_p);

create table qci_ec_product_comments_audit (
        comment_id              integer,
        product_id              integer,
        user_id                 integer,
        user_comment            varchar(4000),
        one_line_summary        varchar(300),
        rating                  numeric,
        approved_p              boolean,
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);

create function qci_ec_product_comments_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_product_comments_audit (
        comment_id, product_id, user_id,
        user_comment, one_line_summary, rating, approved_p,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.comment_id, old.product_id, old.user_id,
        old.user_comment, old.one_line_summary, old.rating, old.approved_p,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address      
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_product_comments_audit_tr
after update or delete on qci_ec_product_comments
for each row execute procedure qci_ec_product_comments_audit_tr ();


create sequence qci_ec_product_review_id_seq start 1;
create view qci_ec_product_review_id_sequence as select nextval('qci_ec_product_review_id_seq') as nextval;

-- reviews made by professionals of the products
create table qci_ec_product_reviews (
        review_id               integer not null primary key,
        product_id              integer not null references qci_ec_products,
        author_name             varchar(100),
        publication             varchar(100),
        review_date             timestamptz,
        -- in HTML format
        review                  text,
        display_p               boolean,
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null
);

create index qci_ec_product_reviews_idx on qci_ec_product_reviews (product_id);
create index qci_ec_product_reviews_idx2 on qci_ec_product_reviews (display_p);

create table qci_ec_product_reviews_audit (
        review_id               integer,
        product_id              integer,
        author_name             varchar(100),
        publication             varchar(100),
        review_date             timestamptz,
        -- in HTML format
        review                  text,
        display_p               boolean,
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);

create function qci_ec_product_reviews_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_product_reviews_audit (
        review_id, product_id,
        author_name, publication, review_date,
        review,
        display_p,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.review_id, old.product_id,
        old.author_name, old.publication, old.review_date,
        old.review, 
        old.display_p,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address      
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_product_reviews_audit_tr
after update or delete on qci_ec_product_reviews
for each row execute procedure qci_ec_product_reviews_audit_tr ();

-- I could in theory make some hairy system that lets them specify
-- what kind of form element each field will have, does 
-- error checking, etc., but I don't think it's necessary since it's 
-- just the site administrator using it.  So here's a very simple
-- table to store the custom product fields:
create table qci_ec_custom_product_fields (
        field_identifier        varchar(100) not null primary key,
        field_name              varchar(100),
        default_value           varchar(100),
        -- column type for oracle (i.e. text, varchar(50), integer, ...)
        column_type             varchar(100),
        creation_date           timestamptz,
        active_p                boolean default 't',
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null
);

create table qci_ec_custom_product_fields_audit (
        field_identifier        varchar(100),
        field_name              varchar(100),
        default_value           varchar(100),
        column_type             varchar(100),
        creation_date           timestamptz,
        active_p                boolean default 't',
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);

create function qci_ec_custom_prod_fields_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_custom_product_fields_audit (
        field_identifier, field_name,
        default_value, column_type,
        creation_date, active_p,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.field_identifier, old.field_name,
        old.default_value, old.column_type,
        old.creation_date, old.active_p,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address              
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_custom_prod_fields_audit_tr
after update or delete on qci_ec_custom_product_fields
for each row execute procedure qci_ec_custom_prod_fields_audit_tr ();

-- more columns are added to this table (by Tcl scripts) when the 
-- administrator adds custom product fields
-- the columns in this table have the name of the field_identifiers
-- in qci_ec_custom_product_fields
-- this table stores the values
create table qci_ec_custom_product_field_values (
        product_id              integer not null primary key references qci_ec_products,
        last_modified           timestamptz not null,
        last_modifying_user     integer not null references users,
        modified_ip_address     varchar(20) not null
);

create table qci_ec_custom_p_field_values_audit (
        product_id              integer,
        last_modified           timestamptz,
        last_modifying_user     integer,
        modified_ip_address     varchar(20),
        delete_p                boolean default 'f'
);

create function qci_ec_custom_p_f_values_audit_tr ()
returns opaque as '
begin
        insert into qci_ec_custom_p_field_values_audit (
        product_id,
        last_modified,
        last_modifying_user, modified_ip_address
        ) values (
        old.product_id,
        old.last_modified,
        old.last_modifying_user, old.modified_ip_address      
        );
	return new;
end;' language 'plpgsql';

create trigger qci_ec_custom_p_f_values_audit_tr
after update or delete on qci_ec_custom_product_field_values
for each row execute procedure qci_ec_custom_p_f_values_audit_tr();

   
   
