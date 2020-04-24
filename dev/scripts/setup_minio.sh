#!/bin/sh


# configure minio
mc config host add minio http://s3:9000 minio letmeinplease

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
      "Action": "*",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::mybucket/*"
      ],
      "Sid": "AllowAllMyBucket"
    }
  ]
}
EOF

mc admin policy add minio allowall allowall.json

mc admin user add minio myuser myuserletmein
mc admin group add minio mygroup myuser

mc admin policy set minio allowall group=mygroup
