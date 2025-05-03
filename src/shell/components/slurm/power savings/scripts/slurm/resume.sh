#!/bin/bash
# Example ResumeProgram
echo "`date` Resume invoked $0 $*" >> /var/log/power_save.log
hosts=`scontrol show hostnames $1`
for host in $hosts
do
   echo "Starting up " $host >> /var/log/power_save.log
   sudo "$(dirname "$0")/../node_management/node_startup.sh" $host &>> /var/log/power_save.log
done
