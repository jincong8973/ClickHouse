#!/usr/bin/env bash
# Tags: long, replica

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh
# shellcheck source=./mergetree_mutations.lib
. "$CURDIR"/mergetree_mutations.lib

$CLICKHOUSE_CLIENT --query="DROP TABLE IF EXISTS indices_mutaions1;"
$CLICKHOUSE_CLIENT --query="DROP TABLE IF EXISTS indices_mutaions2;"


$CLICKHOUSE_CLIENT --query="
CREATE TABLE indices_mutaions1
(
    u64 UInt64,
    i64 Int64,
    i32 Int32,
    INDEX idx (i64, u64 * i64) TYPE minmax GRANULARITY 1
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/$CLICKHOUSE_TEST_ZOOKEEPER_PREFIX/indices_mutaions', 'r1')
PARTITION BY i32
ORDER BY u64
SETTINGS index_granularity = 2, index_granularity_bytes = '10Mi';

CREATE TABLE indices_mutaions2
(
    u64 UInt64,
    i64 Int64,
    i32 Int32,
    INDEX idx (i64, u64 * i64) TYPE minmax GRANULARITY 1
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/$CLICKHOUSE_TEST_ZOOKEEPER_PREFIX/indices_mutaions', 'r2')
PARTITION BY i32
ORDER BY u64
SETTINGS index_granularity = 2, index_granularity_bytes = '10Mi';"


$CLICKHOUSE_CLIENT --query="INSERT INTO indices_mutaions1 VALUES
(0, 2, 1),
(1, 1, 1),
(2, 1, 1),
(3, 1, 1),
(4, 1, 1),
(5, 2, 1),
(6, 1, 2),
(7, 1, 2),
(8, 1, 2),
(9, 1, 2)"

$CLICKHOUSE_CLIENT --query="SYSTEM SYNC REPLICA indices_mutaions2"

$CLICKHOUSE_CLIENT --query="SELECT count() FROM indices_mutaions2 WHERE i64 = 2 SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0;"
$CLICKHOUSE_CLIENT --query="SELECT count() FROM indices_mutaions2 WHERE i64 = 2 SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0 FORMAT JSON;" | grep "rows_read"

$CLICKHOUSE_CLIENT --query="ALTER TABLE indices_mutaions1 CLEAR INDEX idx IN PARTITION 1;" --replication_alter_partitions_sync=2 --mutations_sync=2

$CLICKHOUSE_CLIENT --query="SELECT count() FROM indices_mutaions2 WHERE i64 = 2 SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0;"
$CLICKHOUSE_CLIENT --query="SELECT count() FROM indices_mutaions2 WHERE i64 = 2 SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0 FORMAT JSON;" | grep "rows_read"

$CLICKHOUSE_CLIENT --query="ALTER TABLE indices_mutaions1 MATERIALIZE INDEX idx IN PARTITION 1;" --replication_alter_partitions_sync=2 --mutations_sync=2

$CLICKHOUSE_CLIENT --query="SELECT count() FROM indices_mutaions2 WHERE i64 = 2 SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0;"
$CLICKHOUSE_CLIENT --query="SELECT count() FROM indices_mutaions2 WHERE i64 = 2 SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0 FORMAT JSON;" | grep "rows_read"

$CLICKHOUSE_CLIENT --query="DROP TABLE indices_mutaions1"
$CLICKHOUSE_CLIENT --query="DROP TABLE indices_mutaions2"
