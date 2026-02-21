### Running:

```shell
# Build JAR
mvn clean package

# Deploy Infra
terraform apply --var-file=terraform.tfvars

# Setup controller
CONTROLLER_IP=$(terraform output -raw controller_public_ip)
SCALE_FACTOR=10
NODE_COUNT=5
./deploy/upload-benchmark.sh "$CONTROLLER_IP" "$SCALE_FACTOR" "$NODE_COUNT"

# Setup all nodes
ssh root@"$CONTROLLER_IP"
cd /root/benchmark
./deploy/controller/setup-all-nodes.sh $NODE_COUNT

# Run
ssh root@"$CONTROLLER_IP"
cd /root/benchmark

# Ensure .env has correct ACTIVE_DB set before running
# The parameter in ./run-benchmark is used to identify the folder for the
# Scripts, it does not set the Database for the Java app

./deploy/run-benchmark.sh cockroachdb $NODE_COUNT $SCALE_FACTOR
./deploy/run-benchmark.sh tidb $NODE_COUNT $SCALE_FACTOR
./deploy/run-benchmark.sh citus $NODE_COUNT $SCALE_FACTOR

# Accessing dashboards (tunnel remote via controller)
# Cockroach
ssh -L 8080:10.0.1.20:8080 root@$CONTROLLER_IP

# TiDB - Dashboard & Grafana
# IPs depend on topology
ssh -L 2379:10.0.1.22:2379 root@$CONTROLLER_IP
ssh -L 9090:10.0.1.20:9090 root@$CONTROLLER_IP
ssh -L 3000:10.0.1.20:3000 root@$CONTROLLER_IP


# Collect results
scp -r root@"$CONTROLLER_IP":/root/benchmark/results ./results 

terraform destroy
```

### Node Allocation

| Nodes |   CockroachDB  |                TiDB               |            Citus           |
|:-----:|:--------------:|:---------------------------------:|:--------------------------:|
| 3     | 3 CockroachDB  | 3 TiKV + co-located 3 PD + 1 TiDB | 1 coordinator + 2 workers  |
| 5     | 5 CockroachDB  | 5 TiKV + co-located 3 PD + 1 TiDB | 1 coordinator + 4 workers  |
| 10    | 10 CockroachDB | 7 TiKV + 3 dedicated PD/TiDB      | 1 coordinator + 9 workers  |
| 15    | 15 CockroachDB | 12 TiKV + 3 dedicated PD/TiDB     | 1 coordinator + 14 workers |
| 20    | 20 CockroachDB | 17 TiKV + 3 dedicated PD/TiDB     | 1 coordinator + 19 workers |