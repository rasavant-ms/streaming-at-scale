#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# get EH connection string 
export EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)

# Create file connect-distributed.properties
echo
echo "***** Creating connect-distributed.properties file"
echo

cat > connect-distributed.properties << EOF

    bootstrap.servers=$EVENTHUB_NAMESPACE.servicebus.windows.net:9093
    group.id=connect-cluster-group

    # connect internal topic names, auto-created if not exists
    config.storage.topic=connect-cluster-configs
    offset.storage.topic=connect-cluster-offsets
    status.storage.topic=connect-cluster-status

    # internal topic replication factors - auto 3x replication in Azure Storage
    config.storage.replication.factor=1
    offset.storage.replication.factor=1
    status.storage.replication.factor=1

    rest.advertised.host.name=connect
    offset.flush.interval.ms=10000

    key.converter=org.apache.kafka.connect.json.JsonConverter
    value.converter=org.apache.kafka.connect.json.JsonConverter
    internal.key.converter=org.apache.kafka.connect.json.JsonConverter
    internal.value.converter=org.apache.kafka.connect.json.JsonConverter

    internal.key.converter.schemas.enable=false
    internal.value.converter.schemas.enable=false

    # required EH Kafka security settings
    security.protocol=SASL_SSL
    sasl.mechanism=PLAIN
    sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="\$ConnectionString" password="$EVENTHUB_CS";

    producer.security.protocol=SASL_SSL
    producer.sasl.mechanism=PLAIN
    producer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="\$ConnectionString" password="$EVENTHUB_CS";

    consumer.security.protocol=SASL_SSL
    consumer.sasl.mechanism=PLAIN
    consumer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="\$ConnectionString" password="$EVENTHUB_CS";

    plugin.path=$KAFKA_FOLDER/libs # path to the libs directory within the Kafka release 

EOF

echo
echo "connect-distributed.properties file has been create in the current folder."
echo "***** Done"
