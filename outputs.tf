output "elb_dns_name" {
  value = "${aws_elb.web.dns_name}"
}

output "instance_ip_address" {
    value = "${aws_instance.web.public_ip}"
}

output "rds_sql_hostname" {
    value = "${aws_db_instance.wordpressdb.address}"
}

output "cloudfront_domain" {
    value = "${aws_cloudfront_distribution.wordpress.domain_name}"
}