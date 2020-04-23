# TAXI - Proof of Concept
**TAXI** stands for *Translation Automation eXchange Interface*.

## Setup
### Dependencies
```sh
gem install bundler:2.1.4
bundle install
bundle exec bin/taxi --help
```

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
aws s3 --endpoint-url http://localhost:9000 --profile minio mb s3://docs.com
```
2. Then, upload documents
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio cp /tmp/build/html s3://docs.com --recursive
```
3. List the documents just created
```sh
aws s3 --endpoint-url http://localhost:9000 --profile minio ls s3://docs.com
```

### Development
At this point, both the SFTP server and the S3 clone are up and running.
You may create more buckets and add more content at this point.

## TODO
* [ ] Add multiple users to SFTP
* [ ] SFTP: Mount user config file for users, and generate the keys according to the user names in that config
