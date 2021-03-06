#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "reading Kafka Broker IPs from AKS"
kafka_hostnames=$(kubectl get services -n kafka --no-headers | awk '{print $4}')

kafka_brokers=""
for host in $kafka_hostnames; do
    kafka_brokers="$kafka_brokers,$host:9094"
done

#remove initial comma from string
export KAFKA_BROKERS=${kafka_brokers:1}
export KAFKA_SECURITY_PROTOCOL=PLAINTEXT
export KAFKA_SASL_MECHANISM=
export KAFKA_SASL_JAAS_CONFIG=
export KAFKA_SASL_JAAS_CONFIG_DATABRICKS=
