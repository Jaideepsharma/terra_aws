provider "aws" {
  region = "ap-south-1"
  profile = "jaideep"
}


//CREATING KEY

resource "tls_private_key" "keygen" {
  algorithm   = "RSA"
}


resource "aws_key_pair" "keycc1" {
  key_name   = "keycc1"
  public_key = tls_private_key.keygen.public_key_openssh
}

//FOR SECURITY GROUP

resource "aws_security_group" "sg" {
  name        = "sg"
  description = "ssh, httpd"
  vpc_id      = "vpc-ebf7ea83"


  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "sg"  
}


}

//CREATING INSTANCE

resource "aws_instance" "webserver"{
    ami                 = "ami-0447a12f28fddb066"
    instance_type        = "t2.micro"
    key_name            = "key3"
    availability_zone    = "ap-south-1a"
    security_groups=      [ "sg" ]
    
    connection{
        type            = "ssh"
        user            = "ec2-user"
        private_key        = file("C:/Users/HP/Downloads/key3.pem")
        host            = aws_instance.webserver.public_ip
    }
    
    provisioner "remote-exec"{
        inline = [
            "sudo yum install httpd  php git -y",
            "sudo systemctl start httpd",
            "sudo systemctl enable httpd",
        ]
    }

    tags = {
        Name = "webserver"  
    }
  
}

//CREATING EBS VOLUME

resource "aws_ebs_volume" "vol1" {
    availability_zone    = aws_instance.webserver.availability_zone
    size                = 1
    tags = {
        Name             = "vol1"
    }
}

//ATTACHING THE EBS VOLUME

resource "aws_volume_attachment" "vol1att" {
    device_name            = "/dev/sdh"
    volume_id              = aws_ebs_volume.vol1.id
    instance_id            = aws_instance.webserver.id
    force_detach           = true
}
    
resource "null_resource" "null1"{
    depends_on = [
        aws_volume_attachment.vol1att,
    ]
    
    connection{
        private_key        = file("C:/Users/HP/Downloads/key3.pem")
        
        type               = "ssh"
        user               = "ec2-user"
        host               = aws_instance.webserver.public_ip
    }
    
    provisioner "remote-exec"{
        inline = [
            "sudo mkfs.ext4 /dev/xvda",
            "sudo mount /dev/xvda /var/www/html",
            "sudo rm -rf /var/www/html/*",
            "sudo git clone https://github.com/Jaideepsharma/terra_aws.git  /var/www/html"
        ]
    }
}

//CREATING THE S3 BUCKET

resource "aws_s3_bucket" "hopes3" {
    bucket                = "hopes3"
    acl                   = "private"
    region                = "ap-south-1"
    tags = {
        Name              = "s3_bucket"
    }
}
locals {
    s3_origin_id          = "s3_origin"
}

//PUBLIC S3

resource "aws_s3_bucket_public_access_block" "hopes3_public" {
    bucket = "hopes3"
    block_public_acls = false
    block_public_policy = false
}

//UPLOADING THE FILE TO THE BUCKET

resource "aws_s3_bucket_object" "hopes3_object" {
    
    depends_on = [
        aws_s3_bucket.hopes3,
    ]
    bucket                = "hopes3"
    key                   = "image.jpg"
    source                = "C:/Users/HP/Downloads/image.jpg"
}

//CREATING THE CLOUDFRONT DISTRIBUTION

resource "aws_cloudfront_distribution" "cd" {
    origin{
        domain_name       = aws_s3_bucket.hopes3.bucket_regional_domain_name
        origin_id         = local.s3_origin_id
    }
    
    enabled               = true
    is_ipv6_enabled       = true

    default_cache_behavior {
        allowed_methods   = ["DELETE","PATCH","OPTIONS","POST","PUT","GET", "HEAD"]
        cached_methods    = ["GET", "HEAD"]
        target_origin_id  = local.s3_origin_id

        forwarded_values {
            query_string  = false

            cookies {
                forward   = "none"
            }
        }

        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
        compress               = true
        viewer_protocol_policy = "allow-all"
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}


resource "null_resource" "opencmd"  {


depends_on = [
    null_resource.null1,
  ]

	provisioner "local-exec" {
	    command = "start chrome ${aws_instance.webserver.public_ip} "
  	}
}

