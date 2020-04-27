#!/bin/sh


HOST=s3
BUCKETS="wcd nov pdo cps mps"
LOG=/dev/null

mc config host add ${HOST} http://${HOST}:9000 "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" --api S3v4

cat > allowall.json << EOF
{
    "Statement": [
        {
            "Sid": "AllowAll",
            "Principal": {
                "AWS": "arn:aws:iam::123456789000:role/minio"
            },
            "Resource": [
                "arn:aws:s3:::*"
            ],
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:ListAllMyBuckets",
                "s3:GetBucketLocation"
            ]
        },
        {
            "Sid": "AllowAllBucket",
            "Principal": {
                "AWS": "arn:aws:iam::123456789000:role/minio"
            },
            "Resource": [
                "arn:aws:s3:::*"
            ],
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ]
        }
    ],
    "Version": "2012-10-17"
}
EOF

mc admin policy add ${HOST} allowall allowall.json
mc admin user add ${HOST} myuser myuserletmein
mc admin group add ${HOST} mygroup myuser
mc admin policy set ${HOST} allowall group=mygroup

for bucket in ${BUCKETS}; do
  mc mb ${HOST}/${bucket}
  mc policy set download ${HOST}/${bucket}
done
