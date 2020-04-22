# Translation - Proof of Concept

## Setup

### Dev Environment
```sh
cd dev/
./generate_keys.sh
docker-compose up
```

#### Access
Log into the SFTP server:
```sh
sftp -P 2222 -i sft-keys/agency_rsa_key agency@localhost
```

Access the S3 bucket interface:
```sh
open http://localhost:9000
# or
open http://localhost:9000/path/to/document
```
