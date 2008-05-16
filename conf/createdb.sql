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
  user_id       int         unsigned not null, # �桼��ID
  reg_date      int         unsigned not null, # ��������
  user_st       tinyint              not null, # �桼�����ơ�����
  serv_st       tinyint              not null, # �����ӥ����ơ�����
  
  carrier       char(1)              not null, # ����ꥢ ( D | A | V )
  model_name    varchar(20)          not null, # ���ߤε���̾
  subscr_id     varchar(40)                  , # ���֥����饤��ID
  serial_id     varchar(30)                    # SIM������ / ü��ID

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

