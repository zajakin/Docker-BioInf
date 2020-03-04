#!/usr/bin/bash
sudo apt update
sudo apt upgrade
sudo apt dist-upgrade
if [ `docker images docker-bioinf | wc -l` -lt 2 ]; then
	sudo apt install docker-compose quota -y
	sudo addgroup $USER docker
	sudo systemctl enable docker
	cat /etc/fstab | grep quota  # should be usrquota,grpquota   sudo mcedit /etc/fstab
	sudo quotacheck -ugM /
	read -p "To apply changes please restart computer.
		Press enter to continue"
	# sudo reboot
	sudo quota -vs $USER
	# docker network create --driver macvlan --subnet=10.1.2.0/22 --gateway=10.1.0.1 -o parent=eno1 dockers-net
	
	sudo mkdir -p /data
	sudo chmod +rx /data
	sudo chown $USER /data
	docker volume create --opt type=none --opt device=/data --opt o=bind,size=2TB --name data
	
	docker pull debian:testing
	rm -r Docker-BioInf
	mkdir Docker-BioInf
	if [ ! -e "Docker-BioInf/Dockerfile" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/Dockerfile -O Docker-BioInf/Dockerfile ; fi
	docker build -t docker-bioinf Docker-BioInf
fi
if [ ! -e "Docker-BioInf-per-student.sh" ]; then
	wget --no-cache https://github.com/zajakin/Docker-BioInf/raw/master/Docker-BioInf-per-student.sh -O Docker-BioInf-per-student.sh
	chmod +x Docker-BioInf-per-student.sh
fi
if [ ! -e "users.tsv" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/sample_users.tsv -O users.tsv ; fi

# Add users and create Dockers
grep -v "^#" users.tsv | uniq | tr '\t' ' ' | sudo xargs -l -P 10 ./Docker-BioInf-per-student.sh

exit  # Not start later code automatically
# check users and space
cat /etc/passwd | grep /home/
sudo repquota -s /
docker images
docker ps -a
docker volume ls
docker system df
docker system df -v

# Delete user*
ls .. | grep user
ls .. | grep user | xargs -l -P 10 docker stop
ls .. | grep user | xargs -l -P 10 docker rm
ls .. | grep user | xargs -l -P 10 docker volume rm
ls .. | grep user | xargs -l sudo userdel --remove
ls .. | grep user

# Delete specific user
nuser="user00"
echo $nuser
docker top $nuser 
docker stop $nuser 
docker rm $nuser 
docker volume rm $nuser
sudo userdel --remove $nuser

# Stop all dockers
docker stop $(docker ps -a -q)
# Remove no active dockers
docker rm $(docker ps -a | grep "Exited" | awk '{print $1}')
# Remove all dockers
# docker rm $(docker ps -a -q)
# Remove all docker images
# docker rmi $(docker images -q)
# Remove docker images without correct names
docker rmi $(docker images | grep "<none> .*<none>" | awk '{print $3}') 
