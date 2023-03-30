set serveroutput on
declare
--get name and pk of tables that have pk(date type) =number
cursor get_table_info_np
is
   SELECT distinct cols.table_name, cols.column_name
FROM user_constraints cons, user_cons_columns cols ,user_tab_columns uc
WHERE cons.constraint_type = 'P'
AND cons.constraint_name = cols.constraint_name
And cols.column_name=UC.COLUMN_NAME
And uc.data_type=upper('number')
ORDER BY cols.table_name ;
--get  sequence names
cursor get_seq_name
is
select sequence_name from user_sequences;
--get triggers that insert in column who is a primary key of specific table
cursor get_trigger_info 
is
 select tr.TRIGGER_NAME ,T.COLUMN_NAME ,TR.TABLE_NAME  from user_triggers tr,user_trigger_cols t 
 where T.TABLE_NAME=TR.TABLE_NAME and
  tr.TRIGGER_TYPE ='BEFORE EACH ROW' and tr.TRIGGERING_EVENT='INSERT' and  tr.BASE_OBJECT_TYPE='TABLE' ;
 
     Fnd BOOLEAN;
v_max number(20);
begin


for rec in get_table_info_np 
loop
fnd :=false;
--drop sequence that have name like table name
for i in get_seq_name
loop
if i.sequence_name like '%'||rec.table_name||'%'
then
execute immediate 'drop sequence  '||i.sequence_name;
--dbms_output.put_line('drooped sequence name  '||i.sequence_name);
end if;
end loop;
--create sequence start with max value of pk column +1
execute immediate 'select nvl(max ('|| rec.column_name ||'+1),0) from ' ||rec.table_name 
            into v_max; 

 Execute immediate 'CREATE SEQUENCE  '||rec.table_name||'_SEQ'||
 ' START WITH '||v_max||'  MAXVALUE 999999 INCREMENT BY 1 ';
 --check if there is a trigger that insert in a pk of this table replace it with a new trigger
 for j in get_trigger_info
 loop
 if j.table_name=rec.table_name and j.column_name=rec.column_name
 then
 fnd := true;
 Execute immediate 'CREATE or replace TRIGGER  '||j.trigger_name||
    ' BEFORE INSERT
     ON  '||rec.table_name||
     '  FOR EACH ROW
     BEGIN
     :new.'||rec.column_name||'  :=  '||rec.table_name||'_SEQ.nextval;
     END;';
 end if;
 end loop ;
 --if there isn't a trrigger foe this table create one for it 
if  not fnd then 
--dbms_output.put_line('tables that have not trrigger  '||rec.table_name);

Execute immediate 'CREATE  TRIGGER  '||rec.table_name||'_TRG'
      ||' BEFORE INSERT
     ON  '||rec.table_name||
     '  FOR EACH ROW
     BEGIN
     :new.'||rec.column_name||'  :=  '||rec.table_name||'_SEQ.nextval;
     END;';
   
end if;

end loop;
end;