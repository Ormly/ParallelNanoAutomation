# ParallelNanoAutomation
This respository includes three parts: 

* installation and part of maintaining bash scripts
* ansible playbooks for part of maintaining tasks
* scripts to test automation

## Installation of Ansible
Installe Ansible in computer node only. As some function is missing before version 2.7, we will try to install the latest version
```
$ sudo apt install software-properties-common
$ sudo apt-add-repository ppa:ansible/ansible
$ sudo apt update

$ sudo apt install ansible
```
## How to use Ansible
* To check if ansible and connection is working, we can ping all machines by Ansible. If error in ssh username/password/address, check inventory.ini
```
ansible all -m ping 
```
* To run a playbook, ```-e``` is the external var which is required by playbook. For the specific demand, see the individual playbook
```
ansible-playbook ./playbooks/XXXXX.yml -e target=XXXX
```
or
```
ansible-playbook ./playbooks/XXXXX.yml -e "target=XXXX package=XXXXX"
```
## Configuration
```ansible.cfg``` is to change the default setting.
```
[defaults]
timeout = 30
strategy = free
host_key_checking = False
inventory = ./inventory.ini
```
```timeout = 30```, error occur sometime because of timeout in privilege escalation promt. Extend the timeout to solve this problem  
```strategy = free```, to prevent that Ansible do not go to the next tasks until all hosts finished the current tasks   
```host_key_checking = False```, to prevent the SSH authenticity check block the progress  
```inventory = ./inventory.ini```, to indicate the customize inventory. Otherwise, we would need to indicate in command  
## Bash script and Ansible
One of the advantage of Ansible for us is that Ansible can easily reach to hosts.
Since the team has expert of Bash script and is new to Ansible, we decide to combine both solution in our automation. 
Scripts, which runs in server nodes directly, are not integrated with Ansible. In another word, those scripts are executed directly in server node. 
Scripts, which runs on compute nodes, are integrated with Ansible playbook.
