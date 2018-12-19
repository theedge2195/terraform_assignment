#--- IAM ---

#RDS_Access
resource "aws_iam_instance_profile" "rds_access_profile" {
  name = "rds_access"
  role = "${aws_iam_role.rds_access_role.name}"
}

resource "aws_iam_role_policy" "rds_access_policy" {
  name = "rds_access_policy"
  role = "$(aws_iam_role.rds_access_role.id)"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "rds:*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "rds_access_role" {
  name = "rds_access_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
            "Action": "sts:AssumeRole",
            "Principle": {
                    "Service": "ec2.amazonaws.com"
    },
            "Effect": "Allow",
            "Sid": ""
            }
    ]
}
EOF
}