!/bin/sh
set -e

INSTANCE_DIR=$1
echo "Copying Config files from S2I build"
cp -v $AMQ_HOME/conf/* ${INSTANCE_DIR}/etc/
cp -v /etc/amq/ext/etc/* ${INSTANCE_DIR}/etc/

export -Dcom.sun.management.jmxremote=true 
export -Dcom.sun.management.jmxremote.authenticate=false  
export -Dcom.sun.management.jmxremote.ssl=false  
export -Dcom.sun.management.jmxremote.local.only=false 
export -Dcom.sun.management.jmxremote.port=1099  
export -Dcom.sun.management.jmxremote.rmi.port=1099  
export -Djava.rmi.server.hostname=${BROKER_IP}

#echo "Configuring S2I run to start"
#sed -i 's/launch\.sh/launch\.sh start/' /usr/local/s2i/run
