variable "key_name" {
    description = "The key pair that will be used by Terraform to let the connection block tells the provisioner how to communicate with the instance"
    default = "terraform-kp"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "eu-west-1"
}

variable "ami_id" {
    description = "The AMI ID for Amazon Linux 2 AMI (HVM), SSD Volume Type"
    default = "ami-0ce71448843cb18a1"
}


variable "mysql_port" {
    description = "The MySQL port for the database"
    default = 3306
}
 
 
variable "allocated_storage" {
    description = "The size in GBs of the SQL database"
    default = 10
}
 
variable "instance_class" {
    description = "The type of the SQL instance"
    default = "db.t2.micro"
}
 
variable "db_admin" {
    description = "The dbadmin username"
    default = "admin"
}
 
variable "db_password" {
    description = "The dbadmin password"
    default = "Admin123"
}
 
variable "db_name" {
    description = "The database name"
    default = "wordpress"
}