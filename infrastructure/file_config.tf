resource "local_file" "tf_ansible_inventory" {
  content = <<-DOC
    [jenkins]

    ${module.ec2.jenk_ip} ansible_ssh_private_key_file=~/.ssh/terraforminit.pem

    [jenkins:vars]

    ansible_user=ubuntu

    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
    DOC
  filename = "./ansible/inventory"
}

resource "null_resource" "null" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${local.cluster_name}"
  }

  connection {
    type     = "ssh"
    user     = "ubuntu"
    host     = module.ec2.jenk_ip
    private_key = file("~/.ssh/terraforminit.pem")
  }

  depends_on = [
    local_file.tf_ansible_inventory,
    local_file.tf_Jenkinsfile,
    local_file.tf_InsecureRegistry
  ]
}

resource "local_file" "tf_Jenkinsfile" {
  content = <<-DOC
    pipeline{
                agent any
                stages{
                        stage('--Front End--'){
                                steps{
                                        sh '''
                                                image="${module.ec2.jenk_ip}:5000/frontend:build-$BUILD_NUMBER"
                                                docker build -t $image /var/lib/jenkins/workspace/$JOB_BASE_NAME/frontend
                                                docker push $image
                                                ssh ${module.ec2.prod_ip} -oStrictHostKeyChecking=no  << EOF
                                                kubectl set image deployment/frontend frontend=$image
                                        '''
                                }
                        }  
                        stage('--Service1--'){
                                steps{
                                        sh '''
                                                image="${module.ec2.jenk_ip}:5000/rand1:build-$BUILD_NUMBER"
                                                docker build -t $image /var/lib/jenkins/workspace/$JOB_BASE_NAME/randapp1
                                                docker push $image
                                                kubectl set image deployment/randapp1 randapp1=$image
                                        '''
                                }
                        }
                        stage('--Service2--'){
                                steps{
                                        sh '''
                                                image="${module.ec2.jenk_ip}:5000/rand2:build-$BUILD_NUMBER"
                                                docker build -t $image /var/lib/jenkins/workspace/$JOB_BASE_NAME/randapp2
                                                docker push $image
                                                kubectl set image deployment/randapp2 randapp2=$image
                                        '''
                                }
                        }
                        stage('--Back End--'){
                                steps{
                                        sh '''
                                                image="${module.ec2.jenk_ip}:5000/backend:build-$BUILD_NUMBER"
                                                docker build -t $image /var/lib/jenkins/workspace/$JOB_BASE_NAME/backend
                                                docker push $image
                                                kubectl set image deployment/backend backend=$image
                                        '''
                                }
                        }
                }
        }
    DOC
  filename = "../Jenkinsfile"
}

resource "local_file" "tf_InsecureRegistry" {
  content = <<-DOC

{
        "insecure-registries":["${module.ec2.jenk_ip}:5000"]
}
    DOC
  filename = "./daemon.json"
}