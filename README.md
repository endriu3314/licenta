### Data generation:

```shell
git clone https://github.com/electrum/tpch-dbgen.git
cd tpch-dbgen
make
./dbgen -s 1
for f in *.tbl; do sed -i '' 's/|$//' "$f"; done
mv *.tbl ../benchmark/data/tpch/sf1/
```

### Deploy:

Run:

```shell
terraform apply --var-file=terraform.tfvars
```

