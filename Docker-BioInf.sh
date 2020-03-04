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
	wget https://github.com/zajakin/Docker-BioInf/raw/master/Dockerfile
	docker build -t docker-bioinf Docker-BioInf
fi
if [ ! -e "Docker-BioInf-per-student.sh" ]; then
	wget https://github.com/zajakin/Docker-BioInf/raw/master/Docker-BioInf-per-student.sh
	chmod +x Docker-BioInf-per-student.sh
fi
if [ ! -e "users.tsv" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/sample_users.tsv -O users.tsv ; fi
grep -v "^#" users.tsv | uniq | xargs -l -i -P 10 echo {}
# u:b:o:q:p:m
Docker-BioInf-per-student.sh {}

exit  # not start later code

echo $nuser
docker top $nuser 
sudo repquota -s /
docker images
docker ps -a

docker stop $nuser 
docker rm $nuser 
docker volume rm $nuser
docker rmi $nuser/debian 
sudo userdel --remove $nuser

docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)
docker rmi $(docker images -q)

docker rmi $(docker images | grep "<none> .*<none>" | awk '{print $3}') 
docker images
docker ps -a

docker system df
docker system df -v
