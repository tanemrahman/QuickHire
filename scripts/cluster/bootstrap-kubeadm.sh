#!/usr/bin/env bash
set -euo pipefail

MASTER_IP="$1"
SSH_KEY="$2"
WORKER1_IP="$3"
WORKER2_IP="$4"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo /home/ubuntu/init-master.sh"
JOIN_CMD=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "cat /home/ubuntu/join-command.sh")

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$WORKER1_IP" "sudo $JOIN_CMD"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$WORKER2_IP" "sudo $JOIN_CMD"

echo "Cluster bootstrap complete. Verify with:"
echo "ssh -i $SSH_KEY ubuntu@$MASTER_IP 'kubectl get nodes -o wide'"
