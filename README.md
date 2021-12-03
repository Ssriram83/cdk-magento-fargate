# Magento deployment on AWS using ECS/Fargate, RDS, OpenSearch, and EFS deployed with CDK

The goal of this project is to deploy ECS service with Autoscaling, and rely on an ECS cluster using Capacity Providers with an AutoScaling Group.

## The project is Bootstrap with Projen

### Projen installation

```bash
npm install projen
```

#### how to init a project with Projen (just for information):

```bash
$ git init
$ npx projen new awscdk-app-ts
```

This creates a `.projenrc.js` file

you can regenerate with

```bash
npx projen
```

I personally create an alias to launch projen

```bash
alias pj='npx projen'
```

```bash
pj build
```

### Install project dependencies.

The dependencies CDK or npm packages must be installed through Projen (in the `.projenrx.js` file)

example:

```json
  cdkDependencies: [
    '@aws-cdk/aws-certificatemanager',
    '@aws-cdk/aws-ec2',
    '@aws-cdk/aws-ecr',
```

then execute `pj` to install thems

```bash
pj
```

### Project Configuration

First of all, you must specify a stack name that would be used to create your stack. This is done with an environment parameter `CDK_STACK_NAME` which defaults to `magento`.

```bash
export CDK_STACK_NAME=magento42
```

> **IMPORTANT** Note $CDK_STACK_NAME is also used to create database name, and domain names, Valid characters are a-z (lowercase only), 0-9


This variable can exported it in your environment before creating the stack.
Other resources, can also be created based on the stack name, but you can also control this using the CDK context parameters used through Projen, see below:

In the `.projenrc.js` file you can configure how the stack will be deployed inside your AWS Account.

After updating the **context** section you will need to run again `pj` in order to generate the appropriate cdk.json file from the Projen bootstrap structure.

```json
...
  context: {
    vpc_tag_name: 'ecsworkshop-base/BaseVPC', // TAG Name of the VPC to create the cluster into (or 'default' or remove to create new one)
    enablePrivateLink: 'true',

    //os_domain: 'magento-cdk', // default to $CDK_STACK_NAME
    os_master_user_name: 'magento-master-os',

    //db_name: 'magento', // default to env $CDK_STACK_NAME
    db_user: 'magentodbuser',

    route53_domain_zone: 'your-hosted-zone.route53.com',
    //route53_magento_prefix: 'magento', // default to $CDK_STACK_NAME
    //route53_eksutils_prefix: 'eksutils', // default to $CDK_STACK_NAME-eksutils

    magento_user: 'user1',
    magento_debug_task: 'yes',
  },
  ...
```

- **vpc_tag_name** : You can specify a tag name to use existing VPC, or ommit this parameter to create new VPC from CDK
- **enablePrivateLink** if true, enable VPC service endpoints for Cloudwatch, EFS, SecretManager. (@default: no)

OpenSearch cluster parameters (password is generated by CDK and stored in SecretManager with name "$CDK_STACK_NAME-magento-opensearch-admin-password"):

- **os_domain** : the name of the OpenSearch Cluster that the cdk stack will create for you (@default: <stack_name>)
- **os_master_user_name**: the name for the master
- TODO: make rise of os_master_user_password

RDS Database (password is generated by CDK and stored in SecretManager with name "$CDK_STACK_NAME-magento"):

- **db_name**: the name of the db to create (@default: $CDK_STACK_NAME)
- **db_user**: the name of the db user (@default: magentouser)

ECS Cluster

- **route53_domain_zone** (MANDATORY) needs to specify the Route53 zone you want to use to deploy your services
- **route53_magento_prefix**: prefix to uses for exposing Magento service (@default: $CDK_STACK_NAME)
- **route53_eksutils_prefix**: prefix to uses for exposing the Eksutils service (@default: $CDK_STACK_NAME-eksutils )

> **You need to have prior to this created a wildcard certificate for your route53 zone in Certificate Manager and store this arn in Parameter store with key `CertificateArn-<route53_domain_zone>`**

Magento (password is generated by CDK and stored in SecretManager with name "<stackname>-magento-database-password"):)

- **magento_user**: magento user (@default: magento)
- **magento_debug_task**: yes/no - do we start another magento service with just bash (not running magento instance) for debugging or executing scripts (@default no)

## Generate and deploy

Synthesize and generate the CloudFormation template from the CDK Typescript code:

```bash
make synth
```

Deploy the stack into your AWS account

```bash
make deploy
```

## TroubleShoot and debug

### Exec into the task

ECS allows you to exec into a task to have a shell inside your container.
The stack correctly configures the tasks so that you can securely connect inside.

The CloudFomation stack shows you some commands so that you can directly use to exec inside your tasks.

the Makefile can also show you these commands:

```bash
make connect
```

The printed commands can be used to exec into your containers. It uses a helper function that you can put in your PATH or simply source:

```bash
source src/helper.sh
ecs_exec_service magento MagentoServiceDebug magento
```

In case of errors during the connection, you still can use [ecs-exec-checker](https://github.com/aws-containers/amazon-ecs-exec-checker) tool to figure out where the problem is.

### Connect to the Magento Debug Task

If you activate the context parameter `magento_debug_task` then the Stack creates a dedicated Service that is deployed with all same parameters as the Magento task, except, that it doesn't start Magento and don't get exposed through a load balancer. But it is linked with the same, DB, same Opensearch, and the same Elastic Fils system.

You can use this task to interact with your Magento setup or debug things.

### Troubleshoot first install

When Magento starts, it will execute the following command:

```bash
/opt/bitnami/scripts/magento/entrypoint.sh /opt/bitnami/scripts/magento/run.sh
```

If the Task didn't start properly, you can exec into the debug pod and manually execute the previous command to help figure out where comes the problem is. This can be credentials issues, passwords format like for example :

```
In SearchConfig.php line 81:

  Could not validate a connection to Elasticsearch. Could not parse URI: "htt
  ps://magento-master-os:beavqpdh.Kzm4?6WqtJHv4e0Lj3AioyI@search-magento-zwa5
  v3x4br3kgn4y5e5nu6hv7q.eu-west-1.es.amazonaws.com:443"

```

### Install magento demo content

If you want to install specific Magento content, you can use the magentoDebug service to connect into.
Use the Cdk output (or CloudFormation output in console) to get the connect command:exemple : `ecs_exec_service magento2 magento2-MagentoServiceDebugmagentoServiceMagentoServiceDebugService7B086C58-Danj7j20EkiI magento`

This will create a secure shell (The session is encrypted with a dedicated AWS KMS key generated for you by CDK) within your tasks, and all your commands will be stored in a dedicated CloudWatch log group (/ecs/secu/exec/${CDK_STACK_NAME})

Example commands to install Magento sample data (https://github.com/magento/magento2-sample-data):

```bash
cd /bitnami/magento
su - daemon
composer update

php -d memory_limit=-1 bin/magento sampledata:deploy
php -d memory_limit=-1 bin/magento setup:upgrade

php -d memory_limit=-1 bin/magento setup:static-content:deploy -f

php -d memory_limit=-1 bin/magento catalog:image:resize
```

> TODO: deploy sample datas from Dockerfile startup script instead

> TODO: describe how to activate maintenance mode

### Set developper mode

```
php bin/magento deploy:mode:set developer
```

### Update Magento URL manually
Using magento

```
bin/magento setup:store-config:set --base-url="http://www.magento2.com/"
```

or using DB
```
#Exec to the debut Task
ecs_exec_service magento43 magento43MagentoServiceDebug magento

#Connect to the DB
mysql -h $MAGENTO_DATABASE_HOST -u$MAGENTO_DATABASE_USER -p$MAGENTO_DATABASE_PASSWORD -D $MAGENTO_DATABASE_NAME

#query to update
UPDATE core_config_data SET value = 'http://www.example.com/' WHERE path LIKE 'web/unsecure/base_url';
UPDATE core_config_data SET value = 'https://www.example.com/' WHERE path LIKE 'web/secure/base_url';
```

select * from core_config_data WHERE path LIKE 'web/unsecure/base_url';
select * from core_config_data WHERE path LIKE 'web/secure/base_url';
select * from core_config_data WHERE path LIKE 'web/url/redirect_to_base';


### Debug Magento Apache configuration

Check Magento config:

```
php bin/magento config:show
```


Configuration files are :
```
# /opt/bitnami/apache/conf/httpd.conf
# /opt/bitnami/apache/conf/extra/httpd-default.conf
# /opt/bitnami/apache/conf/vhosts/*.conf
# /opt/bitnami/apache/conf/bitnami/bitnami.conf
# /opt/bitnami/apache/conf/bitnami/php.conf
/opt/bitnami/magento/app/etc/env.php
```

grep ServerName  /opt/bitnami/apache/conf/httpd.conf

43 - ecs-magento43magentoservice-2090334181.eu-west-1.elb.amazonaws.com
re
start apache

# Troubleshoot Magento

uses the script to exec into the task

```
ecs_exec_service magento magento-magentoService27FB24D3-VIUJrhZwrS2S magento
```

debug commands

```
apt-get update && apt-get install -y vim
set -o xtrace
/opt/bitnami/scripts/magento/setup.sh | less
source /opt/bitnami/scripts/magento/setup.sh  | more
```

magento execute this script at startup : `/bin/bash /opt/bitnami/scripts/magento/setup.sh`

## Mysql

ensure_dir_exists /bitnami/magento
configure_permissions_ownership /bitnami/magento -d 775 -f 664 -u daemon -g root
magento_wait_for_db_connection $MAGENTO_DATABASE_HOST 3306 magento magentouser 'Passw0rd!'

mysql -h $MAGENTO_DATABASE_HOST -u $MAGENTO_DATABASE_USER -p$MAGENTO_DATABASE_PASSWORD $MAGENTO_DATABASE_NAME

## Elasticsearch

You can test the OpenSearch connection with curl:

```
curl -XPOST -u "$MAGENTO_ELASTICSEARCH_USER:$MAGENTO_ELASTICSEARCH_PASSWORD" "https://$ELASTICSEARCH_HOST/_search" -H "content-type:application/json" -d'
{
"query": {
"match_all": {}
}
}'
```

### Deleting the Stack

The stack is configured to delete the database cluster and OpenSearch cluster, and EFS file system. If you want to be able to keep the data, you will need to update the **removalPolicy** policies of those services in the CDK code.

```typescript
    const db = new DatabaseCluster(this, 'ServerlessWordpressAuroraCluster', {
      engine: DatabaseClusterEngine.AURORA_MYSQL,
      credentials: Credentials.fromPassword(DB_USER, secret),
      removalPolicy: RemovalPolicy.DESTROY, // <-- you can change this -->
      instanceProps: {
        vpc: vpc,
        securityGroups: [rdsSG],
      },
      defaultDatabaseName: DB_NAME,
    });
    ...

    const osDomain = new opensearch.Domain(this, 'Domain', {
      version: opensearch.EngineVersion.OPENSEARCH_1_0,
      domainName: OS_DOMAIN,
      //accessPolicies: [osPolicy], // Default No access policies
      removalPolicy: RemovalPolicy.DESTROY, // <-- you can change this -->
      securityGroups: [openSearchSG],
    ...

    const efsFileSystem = new FileSystem(this, 'FileSystem', {
      vpc,
      securityGroup: efsFileSystemSecurityGroup,
      performanceMode: PerformanceMode.GENERAL_PURPOSE,
      lifecyclePolicy: LifecyclePolicy.AFTER_30_DAYS,
      throughputMode: ThroughputMode.BURSTING,
      encrypted: true,
      removalPolicy: RemovalPolicy.DESTROY,// <-- you can change this -->
    });
```

While we can't delete an ECS Capacity Provider when associated Autoscaling Group still exists, the first attempt to delete the stack may be finished in a `DELETE_FAILED` state. A second delete attempt should properly delete everything.
