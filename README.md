# aws_autoscaling_group_in_terraform
How to deploy autoscaling group from own image, and make it accessible from outside web over HTTP/SSH.

## What does it covers?
Configuration for HTTP server with:
* Autoscaling group
* Load balancer
* Launch template
* Custom VPC with two subnets in a different availability zones opened for outside traffic

## Prerequistes
* linux shell
* installed terraform
* configured ssh key-pair on your own machine [here](https://www.cyberciti.biz/faq/how-to-set-up-ssh-keys-on-linux-unix/)
* configured aws cli authorization on your machine [should look familiar](https://docs.aws.amazon.com/cli/latest/reference/configure/)
* EC2 AMI image with HTTP server (Nginx/Apache)

## Setup
* clone repo
* open main.tf in a text editor
* edit public_key in "aws_key_pair" to match your ssh location
* edit image_id in "aws_launch_template" to match your AMI ID
* change directory to the cloned repository and run "terraform init" in a bash terminal
* run "terraform apply -auto-approve"
* go to AWS -> EC2 -> Load Balancers, copy DNS name and check it's accessability

**NOTE** Remember about keeping costs low by destroying your infrastructure when it is not needed ("terraform destroy -auto-approve") 
