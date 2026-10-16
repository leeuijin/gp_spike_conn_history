psql -f init.sql
nohup ./conn_chk_deamon.sh > /dev/null 2>&1 &
sh max _conn_test.sh
