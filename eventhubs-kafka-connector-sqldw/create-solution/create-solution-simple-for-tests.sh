#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

export PREFIX=''
export KAFKA_FOLDER=''
export LOCATION="eastus"
export EVENTHUB_PARTITIONS=2
export EVENTHUB_CAPACITY=2
export SQL_TABLE_KIND="columnstore"
export SQL_SKU=DW100c

usage() { 
    echo "Usage: $0 -d <deployment-name> -k <kafka-path> [-l <location>] [-p <eh-partitions>] [-t <eh-throughput-units>]"
    echo "-d: <deployment-name> will be used to create resources"
    echo "-k: kafka directory absolute path"
    echo "-l: where to create the resources. Default=$LOCATION"
    echo "-p: number of partitions for event hubs. Default=$EVENTHUB_PARTITIONS"
    echo "-t: number of throughput units for event hubs. Default=$EVENTHUB_CAPACITY"
    echo "-c: test rowstore, columnstore. Default=columnstore"
    
    exit 1; 
}


# Initialize parameters specified from command line
while getopts ":d:k:l:p:t:c:" arg; do
	case "${arg}" in
		d)
			PREFIX=${OPTARG}
			;;
		k)
			KAFKA_FOLDER=${OPTARG}
			;;
		l)
			LOCATION=${OPTARG}
			;;
		p)
			EVENTHUB_PARTITIONS=${OPTARG}
			;;
        t)
			EVENTHUB_CAPACITY=${OPTARG}
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

export RESOURCE_GROUP=$PREFIX

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

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". Azure SQL DW    => SKU: $SQL_SKU, STORAGE_TYPE: $SQL_TABLE_KIND"
echo

echo
echo "***** Setting up Resource Group"
    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"
    source ../components/azure-common/create-resource-group.sh  
    source ../components/azure-storage/create-storage-account.sh     
echo 

echo
echo "***** Setting up Event Hubs"

    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"    
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="out"
    export EVENTHUB_ENABLE_KAFKA="true"
   
    

#   source ../components/azure-event-hubs/create-event-hub.sh   
echo

echo
echo "****** Create property file"

 #   source ../components/azure-event-hubs/create-properties-small.sh

echo 

echo "***** [D] Setting up DATABASE"

    export SQL_TYPE="dw"
    export SQL_SERVER_NAME=$PREFIX"sql"
    export SQL_DATABASE_NAME="streaming"  
    export SQL_ADMIN_PASS="Strong_Passw0rd!"  
    export SQL_TABLE_NAME="rawdata$TABLE_SUFFIX"

    
    source ../components/azure-sql/create-sql.sh
    
echo

