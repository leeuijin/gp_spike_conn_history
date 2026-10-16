#!/bin/bash

# 접속 정보 설정
DB_NAME="gpadmin"
DB_USER="gpadmin"
NUM_CONNS=230
SLEEP_TIME=300  # 커넥션을 유지할 시간 (초 단위, 300초 = 5분)

echo "Greenplum에 ${NUM_CONNS}개의 커넥션을 동시에 엽니다..."

# 1부터 9까지 루프를 돌며 백그라운드(&)로 psql 세션 실행
for i in $(seq 1 $NUM_CONNS); do
    psql -d $DB_NAME -U $DB_USER -c "SELECT pg_sleep($SLEEP_TIME);" &
    echo "커넥션 $i 시작됨 (OS PID: $!)"
done

echo "=========================================================="
echo "9개의 커넥션이 모두 열렸으며, ${SLEEP_TIME}초 동안 유지됩니다."
echo "진행 중인 세션을 강제로 종료하려면 Ctrl + C 를 누르세요."
echo "=========================================================="

# 백그라운드 프로세스들이 모두 종료될 때까지 대기
wait
echo "모든 커넥션이 종료되었습니다."
