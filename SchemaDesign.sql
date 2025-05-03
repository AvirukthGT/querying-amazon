--Amazon Project

--creating tables

--category table
create table category (
	categroy_id int primary key,
	category_name varchar(20)
)

--customer TABLE
create table customer (
	Customer_id int primary key,
	first_name	varchar(30)
	last_name	varchar(20),
	state varchar(20),
	address varchar(5) default ('xxxx')
)

--seller TABLE

create table seller (
	seller_id int primary key,
	seller_name	varchar(25),
	origin varchar(5)

)

--products table 



