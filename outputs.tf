output "alb_dns_name" {
  description = "Direct URL of the Application Load Balancer"
  value       = aws_lb.web_alb.dns_name
}

output "cloudfront_domain_name" {
  description = "Global CloudFront CDN URL for low-latency access"
  value       = aws_cloudfront_distribution.cdn.domain_name
}
