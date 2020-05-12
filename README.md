# TAXI - Proof of Concept
**TAXI** stands for *Translation Automation eXchange Interface*.

## Setup
### Dependencies
```sh
gem install bundler:2.1.4
bundle install
bundle exec bin/taxi --help
```

## Run
```sh
bundle exec bin/taxi
```
To run `taxi` in development mode, set the environment variable `DEV_ENV` which will load `.env` at startup.

## Translations

### Stages and Structure
There are 4 stages in the translation workflow:
1. **open**: ready to be translated by the translation agency
2. **deploy**: translated and ready to be deployed
3. **done**: deployed in production


Overall file structure:
```
SFTP/
- user1/
  - 1_open/
  - 2_deploy/
  - 3_done/
- user2/
  - 1_open/
  - 2_deploy/
  - 3_done/
```

For each category, a folder in the format `<name>-<from>-<to>` has to be present:
```
- 1_open/
  - <name>-<from>-<to>-<date>/
  - wirecard-en_US-ru_RU-20200506/
```


So the complete identifier for a *package* is `<name>-<from>-<to>-<date>`, where the root folder `open` is the status.

### Example Workflow

Using `taxi`, an example workflow would be:
1. `taxi package make`
2. `taxi package translate`
3. Translation
4. `taxi package deploy`

You can use `taxi package status all|open|deploy|done` to check the status of packages.

### Commands
#### package make
```sh
taxi package make <name> <path> [--bucket=<bucket>]
```

Arguments:
* `name`: name of the package (free to choose any name)
* `path`: path to the resources on S3 (results in `s3://<bucket>/<path>`)
* **OPTIONAL** `bucket`: name of the bucket (*Default:*  `$AWS_DEFAULT_BUCKET`)

#### package translate
```sh
taxi package translate <name> [<from>] <to> --agency=<agency>
```

Arguments:
* `name`: name of the package (must match the `name` specified in `package make`)
* **OPTIONAL** `from`: original language (*Default: en_US*)
* `to`: target language (*e.g. ru_RU*)
* `agency`: name of the agency which will get the translation package (AKA user name for SFTP)

#### package deploy
```sh
taxi package deploy <name> <path> [<from>] <to> [--bucket=<bucket>] --agency=<agency>
```

Arguments:
* `name`: name of the package (must match the `name` specified in `package make`)
* `path`: path to the resources on S3 (results in `s3://<bucket>/<path>`)
* **OPTIONAL** `from`: original language (*Default: en_US*)
* `to`: target language (*e.g. ru_RU*)
* **OPTIONAL** `bucket`: name of the bucket (*Default:* `$AWS_DEFAULT_BUCKET`)
* `agency`: name of the agency which translated the package (AKA user name for SFTP)

#### status
```sh
taxi package status <phase>
```

Arguments:
* `phase`: one of `open`, `deploy`, `done` or `all`

## Dev Environment
This section describes the setup of a development environment.

### Setup

**Run once:** Generate SSH keys for the users and setup folder structure
```sh
cd dev/
./init.sh
```

**Start infrastructure**
```sh
docker-compose -f dev/docker-compose.yml up
```

**Stop infrastructure**
```sh
docker-compose -f dev/docker-compose.yml down --remove-orphans
```

### Access

#### SFTP server
Login via Terminal
```sh
sftp -P 2222 -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -i sftp-keys/agency_rsa_key agency@localhost
```

#### S3 Bucket Web Interface
Access the Administration Interface
```sh
open http://localhost:9000
```

#### S3 Bucket Webserver
Directly access files in your-bucket through the webserver
```
open http://localhost:8888/your-name/path/to/document
```

### AWS CLI
AWS CLI setup for minio, see https://docs.min.io/docs/aws-cli-with-minio.html
The credentials that need to be used for `aws configure --profile minio-admin` are:
* Access Key ID: `minio`
* Secret Access Key: `letmeinplease`
* Region: eu-central-1

The credentials that need to be used for `aws configure --profile minio` are:
* Access Key ID: `myuser`
* Secret Access Key: `myuserletmein`
* Region: eu-central-1

#### Sample Configuration
Add to your `~/.aws/config`
```
[profile minio]
region = eu-central-1
output = text
signature_version = s3v4

[profile minio-myuser]
source_profile = minio
region = eu-central-1
output = text
```

Add to your `~/.aws/credentials`
```
[minio]
aws_access_key_id = minio
aws_secret_access_key = letmeinplease

[minio-myuser]
aws_access_key_id = myuser
aws_secret_access_key = myuserletmein
```

Once the AWS CLI has been configured, create a bucket:
1. First, create a bucket
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio mb s3://mybucket
```
2. Then, upload documents
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio cp /tmp/build/html s3://mybucket --recursive
```
3. List the documents just created
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio ls s3://mybucket
```

**Assume Role**

Test the configuration:
```sh
aws --endpoint-url http://localhost:9000 --profile minio sts assume-role --role-arn arn:xxx:xxx:xxx:xxxx --role-session-name term_session --output json
```


### Development
At this point, both the SFTP server and the S3 clone are up and running.
You may create more buckets and add more content at this point.
`taxi` will use the environment variables specified in `.env` if `DEV_ENV=1`.
These variables will set up `taxi` to use the local infrastructure from `dev/docker-compose.yml`.

### TODO
* [x] SFTP: Add multiple users (via `users.conf`)
* [ ] SFTP: Mount user config file for users, and generate the keys according to the user names in that config
