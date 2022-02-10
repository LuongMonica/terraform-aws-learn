# terraform-aws-learn
Learning project done in Summer 2020

Used tf to create some EC2s in 4 subnets: 2 public, 2 private
- used VPC
- routing table
- internet gateway (so public could reach internet)
- nat gateway (so private can reach pub internet)
- elastic load balancer (ELB)
- specific file: multiple-subnets.tf

Used ansible to configure those machines
- Ubuntu and CentOS
- installed nginx, php, etc
- machines hosted a web app
- also used template files (jinja2)
- specific files: provision.ymls & main.tf
