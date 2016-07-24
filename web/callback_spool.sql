use asterisk;
drop table if exists callback_spool;
create table callback_spool (
	id varchar(50) not null,
	src varchar(20) not null,
	dst varchar(20) not null,
	calltime timestamp default CURRENT_TIMESTAMP,
	primary key (id)
);
