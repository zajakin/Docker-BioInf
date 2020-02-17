
Docker-BioInf-per-student.sh -u aaa -i -p -m 

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
