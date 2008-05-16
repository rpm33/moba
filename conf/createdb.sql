grant all privileges on *.* to ###PROJ_NAME###_w@"%";
grant all privileges on *.* to ###PROJ_NAME###_w@"localhost";
grant select         on *.* to ###PROJ_NAME###_r@"%";
grant select         on *.* to ###PROJ_NAME###_r@"localhost";

#---------------------------------------------------------------------
# user db

drop   database if exists ###PROJ_NAME###_user;
create database           ###PROJ_NAME###_user;
use                       ###PROJ_NAME###_user;

create table user_data (
  user_id       int         unsigned not null, # ユーザID
  reg_date      int         unsigned not null, # 入会日時
  user_st       tinyint              not null, # ユーザステータス
  serv_st       tinyint              not null, # サービスステータス
  
  carrier       char(1)              not null, # キャリア ( D | A | V )
  model_name    varchar(20)          not null, # 現在の機種名
  subscr_id     varchar(40)                  , # サブスクライバID
  serial_id     varchar(30)                    # SIMカード / 端末ID

) type=InnoDB;

alter table user_data
 add primary key     (user_id),
 add unique index i1 (subscr_id),
 add unique index i2 (serial_id);

#---------------------------------------------------------------------
# sequence db

drop   database if exists ###PROJ_NAME###_seq;
create database           ###PROJ_NAME###_seq;
use                       ###PROJ_NAME###_seq;

create table seq_user (id int unsigned not null) type=MyISAM;
insert into  seq_user values (10000);

