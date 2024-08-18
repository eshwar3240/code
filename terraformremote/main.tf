provider "aws" {
  region = "ap-south-1"  # Change to your desired region
}

# Create an S3 bucket for kOps state store
resource "aws_s3_bucket" "eshwar_kops_state_store" {
  bucket = "eshwar-kops-state-store-unique"  # Change to a unique bucket name
}

resource "aws_key_pair" "example" {
  key_name   = "eshwar1"  # Replace with your desired key name
  public_key = file("/var/lib/jenkins/.ssh/eshwar1.pub")  # Replace with the path to your public key file
}

# Create an IAM role for EC2 with necessary permissions
resource "aws_iam_role" "kops_ec2_role" {
  name               = "kops_ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Attach the AdministratorAccess policy to the IAM role
resource "aws_iam_role_policy_attachment" "admin_access" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.kops_ec2_role.name
}

# Create an IAM instance profile to associate with the EC2 instance
resource "aws_iam_instance_profile" "kops_instance_profile" {
  name = "kops_instance_profile"
  role = aws_iam_role.kops_ec2_role.name
}

# Create a security group for the Kubernetes cluster
resource "aws_security_group" "eshwar_k8s_sg" {
  name        = "eshwar_k8s_security_group"
  description = "Allow inbound traffic for Kubernetes"

  vpc_id = data.aws_vpc.eshwar_default.id  # Updated reference

  ingress {
    from_port   = 22           # Allow SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change to your IP for better security
  }

  ingress {
    from_port   = 80           # Allow HTTP
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443          # Allow HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10250         # Allow Kubelet API
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "eshwar_default" {
  default = true
}

# Create an EC2 instance with the IAM role attached
resource "aws_instance" "eshwar_k8s_instance" {
  ami                    = "ami-0a4408457f9a03be3"  # Change to a valid AMI ID for your region
  instance_type          = "t2.medium"               # Change to your desired instance type
  key_name               = aws_key_pair.example.key_name  # Change to your key pair name
  iam_instance_profile   = aws_iam_instance_profile.kops_instance_profile.name  # Attach the IAM instance profile

  vpc_security_group_ids = [aws_security_group.eshwar_k8s_sg.id]

  tags = {
    Name = "Eshwar-K8s-Instance"
  }
}

resource "null_resource" "eshwar_kops_cluster" {
  provisioner "file" {
    source      = "setup_kops.sh"  # Path to your local script
    destination = "/tmp/setup_kops.sh"  # Path on the remote instance

    connection {
      type        = "ssh"
      user        = "ec2-user"  # Change this based on your AMI
      private_key = file("/var/lib/jenkins/.ssh/eshwar1")  # Path to your private key
      host        = aws_instance.eshwar_k8s_instance.public_ip  # Use the public IP of the instance
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_kops.sh",  # Make the script executable
      "/tmp/setup_kops.sh ${aws_s3_bucket.eshwar_kops_state_store.bucket}"  # Execute the script with the bucket name
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"  # Change this based on your AMI
      private_key = file("/var/lib/jenkins/.ssh/eshwar1")  # Path to your private key
      host        = aws_instance.eshwar_k8s_instance.public_ip  # Use the public IP of the instance
    }
  }

  depends_on = [
    aws_s3_bucket.eshwar_kops_state_store,
    aws_security_group.eshwar_k8s_sg,
    aws_instance.eshwar_k8s_instance
  ]
}
