#!/usr/bin/env bash

source /usr/local/greenplum-db/greenplum_path.sh

# ==========================================
# 환경 및 임계치 변수 설정
# ==========================================
PGHOST="localhost"
PGPORT="5432"
PGUSER="gpadmin"
PGDATABASE="gpadmin"

# 커넥션 알람 임계치 (%)
THRESHOLD_PCT=80

# 히스토리 보관 주기 (일 단위)
RETENTION_DAYS=14

# 수집 주기 설정 (초 단위)
SLEEP_INTERVAL=5

# ==========================================
# 1. 초기화
# ==========================================
PSQL_CMD="psql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d ${PGDATABASE} -X -q"

# init.sql은 루프 시작 전에 한 번만 실행
${PSQL_CMD} -f ./init.sql

# ==========================================
# 2. 무한 루프 (주기적 수집)
# ==========================================
while true; do
    # 통계 정보 갱신
    ${PSQL_CMD} -c "ANALYZE gp_conn_summary_history;"
    ${PSQL_CMD} -c "ANALYZE gp_conn_spike_history;"

    # 요약 정보 저장
    ${PSQL_CMD} -c "
    INSERT INTO gp_conn_summary_history (collect_time, total_conns, active_conns, idle_conns, max_conns, usage_pct)
    SELECT
        CURRENT_TIMESTAMP,
        curr.total_conn,
        curr.active_conn,
        curr.idle_conn,
        max_c.max_conn,
        ROUND((curr.total_conn::numeric / max_c.max_conn::numeric) * 100, 2) AS usage_pct
    FROM
        (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') max_c,
        (SELECT
            count(*)::int AS total_conn,
            count(*) FILTER (WHERE state = 'active')::int AS active_conn,
            count(*) FILTER (WHERE state LIKE 'idle%')::int AS idle_conn
         FROM pg_stat_activity) curr;
    "

    # 수집된 usage_pct가 임계치(80%) 이상일 때, 초 단위로 그룹핑하여 커넥션 급증(Spike) 기록
    ${PSQL_CMD} -c "
    INSERT INTO gp_conn_spike_history (
        collect_time, backend_start_sec, usename, client_addr, conn_count
    )
    SELECT
        s.collect_time,
        date_trunc('second', a.backend_start) AS backend_start_sec,
        a.usename,
        a.client_addr,
        COUNT(*) AS conn_count
    FROM pg_stat_activity a
    CROSS JOIN (
        SELECT collect_time, usage_pct
        FROM gp_conn_summary_history
        ORDER BY collect_time DESC
        LIMIT 1
    ) s
    WHERE s.usage_pct >= ${THRESHOLD_PCT}
      AND a.pid <> pg_backend_pid()
    GROUP BY
        s.collect_time,
        date_trunc('second', a.backend_start),
        a.usename,
        a.client_addr
    HAVING COUNT(*) > 1;
    "

    # 보관 주기가 지난 히스토리 데이터 삭제
    ${PSQL_CMD} -c "
    DELETE FROM gp_conn_summary_history
    WHERE collect_time < CURRENT_TIMESTAMP - INTERVAL '${RETENTION_DAYS} days';

    DELETE FROM gp_conn_spike_history
    WHERE collect_time < CURRENT_TIMESTAMP - INTERVAL '${RETENTION_DAYS} days';
    "

    # 변수로 지정된 시간(초)만큼 대기
    sleep ${SLEEP_INTERVAL}
done
