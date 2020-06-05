#!/bin/bash
echo "Starting the Polystore user databases and metadata database"
docker-compose -f databases.yaml up -d
echo "Wait for databases"
sleep 60
echo "Start Polystore components"
docker-compose -f polystore.yaml up -d
echo "Typhon Polystore installation completed."
echo "It may take a few minutes for all services to be up and running."
exit 1
