# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

data "aws_availability_zones" "available" {}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create two public subnets to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "public2" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.5.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
}


# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "terraform_sg_elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "terraform_sg"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# the RDS instance over MysQL 3306
resource "aws_security_group" "dbsg" {
    name = "dbsg"
    vpc_id      = "${aws_vpc.default.id}"
    
    ingress {
        from_port = "${var.mysql_port}"
        to_port = "${var.mysql_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
 
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
 
    tags = {
        Name = "RDS-SG"
    }
}

# the Elastic load balancer
resource "aws_elb" "web" {
  name = "terraform-elb"

  subnets         = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# the EC2 instance
resource "aws_instance" "web" {
  # The connection block tells our provisioner how to
  # communicate with the instance
  connection {
    # The default username for our AMI (ec2-user for Amazon Linux 2)
    user = "ec2-user"
    host = self.public_ip
    private_key = "${file("./terraform-kp.pem")}"
    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.default.id}"

  # We run a remote provisioner on the instance after creating it
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum install -y php php-dom php-gd php-mysql",
      "sudo wget -P /tmp https://wordpress.org/wordpress-5.1.1.tar.gz",
      "sudo mount -a",
      "sudo tar xzvf /tmp/wordpress-5.1.1.tar.gz --strip 1 -C /var/www/html",
      "sudo chown -R apache:apache /var/www/html",
      "sudo systemctl enable httpd",
      "sudo sed -i 's/#ServerName www.example.com:80/ServerName www.myblog.com:80/' /etc/httpd/conf/httpd.conf",
      "sudo sed -i 's/ServerAdmin root@localhost/ServerAdmin admin@myblog.com/' /etc/httpd/conf/httpd.conf",
      "sudo chmod -R 755 /var/www/html/wp-content",
      "sudo chown -R apache:apache /var/www/html/wp-content",
      "sudo systemctl start httpd",
      "sudo chkconfig httpd on",
    ]
  }
}

# create the subnet group for the 2 subnets in 2 availability zones to be used by RDS
resource "aws_db_subnet_group" "default" {
  name        = "wordpress-subnet-group"
  description = "Terraform example RDS subnet group"
  subnet_ids  = ["${aws_subnet.default.id}","${aws_subnet.public2.id}"]
}

# create RDS MySQL instance
resource "aws_db_instance" "wordpressdb" {
    identifier = "wordpressdb"
    engine = "mysql"
    engine_version = "5.7"
    db_subnet_group_name = "${aws_db_subnet_group.default.id}"
    allocated_storage = "${var.allocated_storage}"
    instance_class = "${var.instance_class}"
    vpc_security_group_ids = ["${aws_security_group.dbsg.id}"]
    name = "${var.db_name}"
    username = "${var.db_admin}"
    password = "${var.db_password}"
    parameter_group_name = "default.mysql5.7"
    skip_final_snapshot = true
    tags = {
        Name = "WordPress DB"
    }
}

# craete the cloudfront distribution and register the ELB as its origin
resource "aws_cloudfront_distribution" "wordpress" {
  origin {
    domain_name = "${aws_elb.web.dns_name}"
    origin_id   = "${aws_elb.web.id}"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port = "80"
      https_port = "443"
      origin_ssl_protocols = ["TLSv1"]
    }
  }

  enabled             = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_elb.web.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  tags = {
    Environment = "production"
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