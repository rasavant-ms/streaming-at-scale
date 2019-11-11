# Instruction

create-solution.sh is work in progress, creation of EH and property file works fine.
SQL DW has been added and tested once, need to verify if it actually works.

create-solution-simple-for-tests.sh is just a simple script to run quick tests. Can be deleted.

folder 'components' is here just to show I used the same pattern you used for all the other scripts and put the small script to create the property file in the relative path ../components/azure-event-hubs/create-properties-small.sh

create-properties-small.sh retrieves the Connection String from the EH and creates the connect-distributed.properties file. It is currently stored in the local folder, location should be probably changed.
