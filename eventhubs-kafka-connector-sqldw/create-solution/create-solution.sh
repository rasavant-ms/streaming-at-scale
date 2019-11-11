#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

export PREFIX=''
export KAFKA_FOLDER=''
export LOCATION="eastus"
export TESTTYPE="1"
export STEPS="CIDPTMV"
export SQL_TABLE_KIND="columnstore"

usage() { 
    echo "Usage: $0 -d <deployment-name> -k <kafka-path> [-s <steps>] [-t <test-type>] [-l <location>] [-c <sql-table-kind>]"
    echo "-k: kafka directory absolute path"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      D=DATABASE"
    echo "      P=PROCESSING"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "      V=VERIFY deployment"
    echo "-t: test 1,5,10 thousands msgs/sec. Default=$TESTTYPE"
    echo "-l: where to create the resources. Default=$LOCATION"
    echo "-c: test rowstore, columnstore. Default=columnstore"
    exit 1; 
}


# Initialize parameters specified from command line
while getopts ":d:k:s:t:l:c:" arg; do
	case "${arg}" in
		d)
			PREFIX=${OPTARG}
			;;
		k)
			KAFKA_FOLDER=${OPTARG}
			;;
		s)
			STEPS=${OPTARG}
			;;
		t)
			TESTTYPE=${OPTARG}
			;;
		l)
			LOCATION=${OPTARG}
			;;
        c)
			SQL_TABLE_KIND=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$PREFIX" ]]; then
	echo "Enter a name for this deployment."
	usage
fi

if [[ -z "$KAFKA_FOLDER" ]]; then
	echo "Enter the path of your kafka folder"
	usage
fi

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export EVENTHUB_PARTITIONS=16
    export EVENTHUB_CAPACITY=12
    export SQL_SKU=DW100c
    export SIMULATOR_INSTANCES=5

fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=8
    export EVENTHUB_CAPACITY=6
    export SQL_SKU=DW100c
    export SIMULATOR_INSTANCES=3

fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export SQL_SKU=DW100c
    export SIMULATOR_INSTANCES=1 

fi

# last checks and variables setup
if [ -z ${SIMULATOR_INSTANCES+x} ]; then
    usage
fi

export RESOURCE_GROUP=$PREFIX

# remove log.txt if exists
rm -f log.txt

echo "Checking pre-requisites..."

source ../assert/has-local-az.sh
source ../assert/has-local-jq.sh

declare TABLE_SUFFIX=""
case $SQL_TABLE_KIND in
    rowstore)
        TABLE_SUFFIX=""
        ;;
    columnstore)
        TABLE_SUFFIX="_cs"
        ;;
    *)
        echo "SQL_TABLE_KIND must be set to 'rowstore', 'columnstore'"
        exit 1
        ;;
esac

echo
echo "Streaming at Scale with Kafka Connector to Azure DW"
echo "====================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". Azure SQL DW    => SKU: $SQL_SKU, STORAGE_TYPE: $SQL_TABLE_KIND"
echo ". Simulators      => $SIMULATOR_INSTANCES"
echo

echo "Deployment started..."
echo

echo "***** [C] Setting up COMMON resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-common/create-resource-group.sh
        source ../components/azure-storage/create-storage-account.sh

    fi
echo 

echo "***** [I] Setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"    
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="cosmos"
    export EVENTHUB_ENABLE_KAFKA="true"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/create-event-hub.sh
        source ../components/azure-event-hubs/create-properties-small.sh
    fi
echo

 

echo "***** [D] Setting up DATABASE"

    export SQL_TYPE="dw"
    export SQL_SERVER_NAME=$PREFIX"sql"
    export SQL_DATABASE_NAME="streaming"  
    export SQL_ADMIN_PASS="Strong_Passw0rd!"  
    export SQL_TABLE_NAME="rawdata$TABLE_SUFFIX"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-sql/create-sql.sh
    fi
echo

############################# From here below needs to be reviwed and modified

echo "***** [P] Setting up PROCESSING"

    export ADB_WORKSPACE=$PREFIX"databricks" 
    export ADB_TOKEN_KEYVAULT=$PREFIX"kv" #NB AKV names are limited to 24 characters
    export KAFKA_TOPIC="$EVENTHUB_NAME"
    
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../components/azure-event-hubs/get-eventhubs-kafka-brokers.sh
        source ../streaming/databricks/runners/kafka-to-cosmosdb.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/get-eventhubs-kafka-brokers.sh
        source ../simulator/run-generator-kafka.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/report-throughput.sh
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-cosmosdb.sh
    fi
echo

echo "***** Done"



