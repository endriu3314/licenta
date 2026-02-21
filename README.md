### Deploy:

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
./deploy/run-benchmark.sh cockroachdb $NODE_COUNT $SCALE_FACTOR
./deploy/run-benchmark.sh tidb $NODE_COUNT $SCALE_FACTOR
./deploy/run-benchmark.sh citus $NODE_COUNT $SCALE_FACTOR

# Collect results
scp -r root@"$CONTROLLER_IP":/root/benchmark/results ./results 

terraform destroy
```
