# Custom AMQ
If you just need to add your custom broker configuration to the OpenShift image, then the easiest
way is to create and mount a ConfigMap hosting the `broker.xml` content. Instead, if you need to
replace some binary files (i.e. for patching a library), then you can use S2I procedure.

When creating your custom configuration, there are a number of variables that you must use and
will be replaced at runtime with the actual values: in addition to `AMQ_NAME` and `BROKER_IP`,
you also have `AMQ_CLUSTER_USER` and `AMQ_CLUSTER_PASSWORD` in case of clustering.
Note that you should never change any configuration that is managed by the Operator.

## Custom config mount
```sh
AMQ_NAME="my-broker"

# create the ConfigMap holding your custom configuration
oc create configmap broker-config --from-file=broker.xml

# mount the ConfigMap into the AMQ image
oc set volume statefulset $AMQ_NAME-ss --add --overwrite \
    --name=broker-config \
    --mount-path=/opt/amq/conf/broker.xml \
    --sub-path=config/broker.xml \
    --source='{"configMap":{"name":"broker-config"}}'

# restart all broker pods
oc delete pods -l ActiveMQArtemis=$AMQ_NAME
```

## Custom image build
```sh
GITHUB_USER="fvaleri"
API_ENDPOINT="https://$(crc ip):6443"
REG_INTERNAL="image-registry.openshift-image-registry.svc:5000"
ADMIN_NAME="kubeadmin"
ADMIN_PASS="8rynV-SeYLc-h8Ij7-YPYcz"
USER_NAME="developer"
USER_PASS="developer"
PROJECT_NAME="broker"
REG_SECRET="registry-secret"
REG_USER="***"
REG_PASS="***"

# fork, clone, add your custom files in config folder and push
git clone git@github.com:$GITHUB_USER/amq-s2i.git && cd amq-s2i
git commit -am "My custom config" && git push

# login and create a new project
oc login -u $USER_NAME -p $USER_PASS $API_ENDPOINT
oc new-project $PROJECT_NAME

# authenticate to the registry
oc create secret docker-registry $REG_SECRET \
    --docker-server="registry.redhat.io" \
    --docker-username="$REG_USER" \
    --docker-password="$REG_PASS"
oc secrets link default $REG_SECRET --for=pull
oc secrets link builder $REG_SECRET --for=pull
oc secrets link deployer $REG_SECRET --for=pull

# start the custom image build (should end with: Push successful)
oc import-image amq7/amq-broker:7.7 --confirm --from=registry.redhat.io/amq7/amq-broker:7.7 -n $PROJECT_NAME
oc new-build registry.redhat.io/amq7/amq-broker:7.7~https://github.com/$GITHUB_USER/amq-s2i.git && \
    oc set build-secret --pull bc/amq-s2i $REG_SECRET && \
    oc start-build amq-s2i

# check the build and get the image repository
oc logs -f bc/amq-s2i
oc get is | grep amq-s2i | awk '{print $2}'
```

## Deploy via Operator
```sh
# deploy the operator as cluster-admin
oc login -u $ADMIN_NAME -p $ADMIN_PASS $API_ENDPOINT
oc apply -f deploy/service_account.yaml
oc apply -f deploy/role.yaml
oc apply -f deploy/role_binding.yaml
oc apply -f $deploy_dir/crds/broker_activemqartemis_crd.yaml
oc apply -f $deploy_dir/crds/broker_activemqartemisaddress_crd.yaml
oc apply -f $deploy_dir/crds/broker_activemqartemisscaledown_crd.yaml
oc secrets link amq-broker-operator $REG_SECRET --for=pull
oc apply -f deploy/operator.yaml

# deploy the broker (use the custom image repository here)
oc login -u $USER_NAME -p $USER_PASS $API_ENDPOINT
oc apply -f - <<EOF
apiVersion: broker.amq.io/v2alpha2
kind: ActiveMQArtemis
metadata:
  name: my-broker
spec:
  deploymentPlan:
    size: 2
    image: $REG_INTERNAL/$PROJECT_NAME/amq-s2i
    requireLogin: true
    persistenceEnabled: true
    messageMigration: true
    journalType: nio
  console:
    expose: true
  acceptors:
    - name: all
      protocols: all
      port: 61617
EOF
```

## Custom image rebuild
```sh
# do some configuration changes
git commit -am "Config update" && git push

# login and select the project
oc login -u $USER_NAME -p $USER_PASS $API_ENDPOINT
oc project $PROJECT_NAME

# start a new build and trigger a rolling update
oc start-build amq-s2i --follow
oc patch statefulset my-broker-ss -p \
   "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"last-restart\":\"`date +'%s'`\"}}}}}"
```
