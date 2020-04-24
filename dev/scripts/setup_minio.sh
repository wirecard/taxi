#!/bin/sh


HOST=s3
BUCKETS="wcd nov pdo cps mps"
LOG=/dev/null

mc config host add ${HOST} http://${HOST}:9000 "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" --api S3v4

cat > allowall.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action":[
        "s3:CreateBucket",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
     ],
     "Effect": "Allow",
      "Resource": [
            "arn:aws:s3:::*"
         ],
      "Sid": "AllowAll"
    },
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
     "Effect": "Allow",
     "Resource": [
            "arn:aws:s3:::*"
         ],
     "Sid": "AllowAllBucket"
    }
  ]
}
EOF

mc admin policy add ${HOST} allowall allowall.json
mc admin user add ${HOST} myuser myuserletmein
mc admin group add ${HOST} mygroup myuser
mc admin policy set ${HOST} allowall group=mygroup

for bucket in ${BUCKETS}; do
{
  echo creating bucket ${bucket}
  mc mb ${HOST}/${bucket}
  mc policy set download ${HOST}/${bucket}
} >&2
done
