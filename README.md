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
To run the binary in development mode, set the environment variable `DEV_ENV` which will load `.env` at startup.

## Translations

### Stages and Structure
There are 4 stages in the translation workflow:
1. **open**: ready to be translated by the translation agency
2. **review**: ready to be reviewed, adapted and then approved for deployment
3. **deploy**: ready to be deployed
4. **done**: deployed in production


Overall file structure:
```
SFTP/
- open/
- review/
- deploy/
- done/
```

For each category, the following file structure must be present:
```
- open/
  - <project>/
    - 2020-04-22/
      - ru_RU/
      - de_DE/
```

So the complete identifier for a *package* is `<project>/2020-04-22/ru_RU`, where the root folder `open` is the status.
**TBD**: The package `<project>/2020-04-22/ru_RU` will be duplicated or moved to other stages.

Using `taxi`, an example workflow would be:
1. `taxi package make`
2. `taxi package translate`
3. `taxi package review pass`
4. `taxi package deploy`

You can use `taxi package status` or `taxi package status <id>` to check the status of all/one package(s).

## Dev Environment
```sh
cd dev/
./generate_keys.sh
docker-compose up
```

### Access
#### SFTP
Log into the SFTP server:
```sh
sftp -P 2222 -i sftp-keys/agency_rsa_key agency@localhost
```

#### S3/minio
##### Web Interface or Content Access
```sh
open http://localhost:9000
# or
open http://localhost:9000/path/to/document
```

##### AWS CLI
AWS CLI setup for minio, see https://docs.min.io/docs/aws-cli-with-minio.html

1. First, create a bucket
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio mb s3://example.bucket.com
```
2. Then, upload documents
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio cp /tmp/build/html s3://example.bucket.com --recursive
```
3. List the documents just created
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio ls s3://example.bucket.com
```

### Development
At this point, both the SFTP server and the S3 clone are up and running.
You may create more buckets and add more content at this point.

### TODO
* [ ] Add multiple users to SFTP
* [ ] SFTP: Mount user config file for users, and generate the keys according to the user names in that config
