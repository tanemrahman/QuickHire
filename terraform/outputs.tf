output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker1_public_ip" {
  value = aws_instance.worker1.public_ip
}

output "worker2_public_ip" {
  value = aws_instance.worker2.public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "frontend_url_hint" {
  value = "http://${aws_instance.master.public_ip}:30080"
}

output "backend_url_hint" {
  value = "http://${aws_instance.master.public_ip}:30081/api"
}

output "kubeadm_init_hint" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_instance.master.public_ip} 'sudo /home/ubuntu/init-master.sh'"
}

output "worker_join_hint" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_instance.master.public_ip} 'cat /home/ubuntu/join-command.sh'"
}

output "deploy_hint" {
  value = "kubectl apply -f k8s/namespace.yaml -f k8s/configmap.yaml -f k8s/secret.yaml -f k8s/mongo-pv-pvc.yaml -f k8s/mongo-statefulset.yaml -f k8s/backend-deployment.yaml -f k8s/frontend-deployment.yaml -f k8s/services.yaml"
}