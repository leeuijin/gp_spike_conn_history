-- 1. 주기별 커넥션 요약 정보 저장 테이블
CREATE TABLE IF NOT EXISTS gp_conn_summary_history (
    collect_time    TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    total_conns     INT,
    active_conns    INT,
    idle_conns      INT,
    max_conns       INT,
    usage_pct       NUMERIC(5,2)
)
DISTRIBUTED RANDOMLY;

CREATE INDEX IF NOT EXISTS idx_conn_summary_time ON gp_conn_summary_history (collect_time);


-- 2. 임계치 초과 시 상세 커넥션 정보 저장 테이블

CREATE TABLE IF NOT EXISTS gp_conn_spike_history (
    collect_time TIMESTAMP,           -- 데이터 수집 시점
    backend_start_sec TIMESTAMP,      -- 커넥션이 맺어진 시간 (초 단위 절사)
    usename NAME,                     -- 접속 계정
    client_addr INET,                 -- 출발지 IP
    conn_count INT                    -- 해당 1초 동안 맺어진 커넥션 수
) DISTRIBUTED RANDOMLY;

CREATE INDEX IF NOT EXISTS idx_conn_spike_history ON gp_conn_spike_history (collect_time);
