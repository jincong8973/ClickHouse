SELECT toTypeName(topKDistinctState(toNullable(10))(toString(number)) IGNORE NULLS) FROM numbers(100) GROUP BY tuple((map((materialize(toNullable(1)), 2), 4, (3, 4), 5), 3)), map((1, 2), 4, (3, 4), toNullable(5)) WITH CUBE WITH TOTALS FORMAT Null
