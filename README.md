# terraform-aws-learn
Learning project done in Summer 2020

## 1st Proj: Creating some AWS resources using terraform
multiple-subnets.tf created some EC2s in 4 subnets: 2 public, 2 private
- used VPC
- routing table (+ routes, associations, etc)
- internet gateway (so public could reach internet)
- nat gateway (so private can reach pub internet)
- security groups, etc

## 2nd Proj: Creating some AWS resources using terraform and using ansible to configure them to host a web app
main.tf created and defined:
- 2 EC2 instances
- elastic load balancer (ELB)
- provisioners (in order to run ansible at boot)
- security groups, etc

Used ansible to configure those machines
- Ubuntu and CentOS
- installed nginx, php, etc
- instances hosted a web app
- also used template files (jinja2)
- specific files: provision.ymls 
