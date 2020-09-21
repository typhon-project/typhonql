#!/bin/bash
set -e 
dlmodel=$(<"$1")
mlmodel=$(<"$2")
dlmodelRE1=${dlmodel//\"/\\\"}
dlmodelRE=${dlmodelRE1//[$'\t\r\n ']}
mlmodelRE1=${mlmodel//\"/\\\"}
mlmodelRE=${mlmodelRE1//[$'\t\r\n ']}
echo "db.models.insert([{\"_id\":UUID(), \"version\":1, \"initializedDatabases\": false, \"initializedConnections\":true, \"contents\":\"$dlmodelRE\", \"type\":\"DL\", \"dateReceived\":ISODate(), \"_class\":\"com.clms.typhonapi.models.Model\" }, {\"_id\":UUID(), \"version\":1, \"initializedDatabases\":false, \"initializedConnections\":false, \"contents\":\"$mlmodelRE\", \"type\":\"ML\", \"dateReceived\":ISODate(), \"_class\":\"com.clms.typhonapi.models.Model\" }]);" > models/addModels.js
