-- Replicate on all nodes
SELECT create_reference_table('region');
SELECT create_reference_table('nation');

-- Distributed tables
SELECT create_distributed_table('supplier', 's_suppkey');
SELECT create_distributed_table('customer', 'c_custkey');
SELECT create_distributed_table('part', 'p_partkey');

-- Co-located pairs: joined together frequently, same shard
SELECT create_distributed_table('partsupp', 'ps_partkey', colocate_with => 'part');
SELECT create_distributed_table('orders', 'o_orderkey');
SELECT create_distributed_table('lineitem', 'l_orderkey', colocate_with => 'orders');