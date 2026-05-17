SELECT create_reference_table('region');
SELECT create_reference_table('nation');
SELECT create_reference_table('supplier');
SELECT create_reference_table('part');
SELECT create_reference_table('partsupp');
SELECT create_reference_table('customer');

SELECT create_distributed_table('orders',   'o_orderkey');
SELECT create_distributed_table('lineitem', 'l_orderkey', colocate_with => 'orders');