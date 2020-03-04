#!/usr/bin/bash
if [ `docker images Docker-BioInf | wc -l` -lt 2 ]; then
	wget https://github.com/zajakin/Docker-BioInf/raw/master/Docker-BioInf-firstrun.sh
	bash -c ./Docker-BioInf-firstrun.sh
fi
if [ ! -e "Docker-BioInf-per-student.sh" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/Docker-BioInf-per-student.sh ; fi
if [ ! -e "users.tsv" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/sample_users.tsv -O users.tsv ; fi
grep -v "^#" users.tsv | xargs -l echo 
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
