# HPC-Setup

This project is aimed to build HPC cluster from scratch with the following steps, suppose we have one head node and three worker nodes:

1. Install basic Rocky Linux on head nodes, only the head node is equipped with SSD, all compute/worker nodes will PXE boot using warewulf 4.6
2. Configure the network according to warewulf recommended setup at https://warewulf.org/docs/v4.6.x/
3. Configure warewulf, configure rocky linux image and install on compute nodes
4. Install slurm on headnode and worker node
5. Generate scripts to automate this process, also, if Ansible can be used for automation, make it happen and place all necessary scripts under folder Ansible