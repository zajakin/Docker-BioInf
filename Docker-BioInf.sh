#!/usr/bin/bash

# Settings can be edited in "Settings.ini"
if [ -e "Settings.ini" ]; then source Settings.ini
else
tee Settings.ini << END
#for Google smtp_url="smtps://[user[:pass]@]smtp.gmail.com" https://ec.haxx.se/usingcurl/usingcurl-smtp#secure-mail-transfer
smtp_url="smtp://10.1.0.4" # smtp_url="smtp[s]://[user[:pass]@]host[:port]"
admin="admin@edu.eu"
if [ "$base" == "" ] ; then base="serv1.edu.eu" ; fi # Required
alias4SSL="" # "" or "-d second.domain.edu -d test.domain.edu"
if [ "$quota" == "" ] ; then quota="10G" ; fi  # "200M" or "10G" or "1T"
END
source Settings.ini
fi

sudo apt update
sudo apt upgrade -y --no-install-recommends
sudo apt dist-upgrade -y --no-install-recommends
sudo apt autoremove -y
sudo apt autoclean -y
if [ `docker images docker-bioinf | wc -l` -lt 2 ]; then
	sudo apt install docker-compose quota curl letsencrypt -y --no-install-recommends
	sudo addgroup $USER docker
	sudo systemctl enable docker
	cat /etc/fstab | grep quota  # should be usrquota,grpquota   sudo mcedit /etc/fstab
	sudo quotacheck -ugM /
	read -p "To apply changes please restart computer.
		Press enter to continue"
	# sudo reboot
	sudo quota -vs $USER
	# docker network create --driver macvlan --subnet=10.1.2.0/22 --gateway=10.1.0.1 -o parent=eno1 dockers-net
	
	sudo certbot certonly --standalone --preferred-challenges http --allow-subset-of-names --expand -d $base $alias4SSL
	sudo openssl dhparam -out /etc/letsencrypt/dhparam.pem 2048
	sudo chmod 755 /etc/letsencrypt/{archive,live}
	sudo ls -l /etc/letsencrypt/live/$base
	( sudo crontab -l | grep -v -F "certbot renew" ; echo "42 2 * * 7 certbot renew --quiet" ) | sudo crontab -
	docker volume create --opt type=volume --opt device=/etc/letsencrypt --opt o=bind --name cert # -v cert:/cert:ro
	if [ `docker volume ls | grep -c " cert\$"` -ne 1 ] ; then
mkdir -p cert/live/$base/
key=cert/live/$base/privkey.pem
cert=cert/live/$base/fullchain.pem
if [ -e "$cert" ]; then openssl req -x509 -nodes -newkey rsa:2048 -keyout $key -out $cert -batch -days 3650
fi
# cat self.key self.pem > certificate.pem
docker volume create --opt type=volume --opt device=`pwd`/cert --name cert # -v cert:/cert:ro
	fi
	docker pull docker.io/nicolargo/glances
	docker run -d --name=monitoring --restart="always" --net=host --privileged -e GLANCES_OPT="-w" -v /var/run/docker.sock:/var/run/docker.sock:ro --pid host docker.io/nicolargo/glances

	sudo mkdir -p /data
	sudo chmod +rx /data
	sudo chown $USER /data
	docker volume create --opt type=none --opt device=/data --opt o=bind,size=2TB --name data
fi
wget --no-cache https://github.com/zajakin/Docker-BioInf/raw/master/Docker-BioInf-per-student.sh -O Docker-BioInf-per-student.sh
chmod +x Docker-BioInf-per-student.sh
docker pull debian:testing
rm -r Docker-BioInf
mkdir Docker-BioInf
wget --no-cache https://github.com/zajakin/Docker-BioInf/raw/master/Dockerfile -O Docker-BioInf/Dockerfile
docker build -t docker-bioinf Docker-BioInf
sudo certbot renew
if [ ! -e "usedports" ] ; then echo 2 > usedports ; fi
docker ps -a -q | xargs -l docker port  | awk -F ':' '{print substr($2, 1, length($2)-1)}' | sort | uniq > usedports

# Add users and create Dockers
# Download sample of file with users login and pass
if [ ! -e "users.tsv" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/sample_users.tsv -O users.tsv ; fi
# Or generate automatically
# rm users.tsv
if [ ! -e "users.tsv" ]; then 
	count=20
	for i in {300..650}
	do
[ `grep -c "^$i$" usedports` != 0 ] && continue
[ -e "users.tsv" ] && [ `grep -c -P "\-o\t$i\t" users.tsv` != 0 ] && continue
echo -e "-u\tuser$i\t-b\t$base\t-o\t$i\t-q\t$quota\t-p\t$(cat /dev/urandom | tr -dc a-zA-Z0-9 | head -c8)\t-s\th\t-m\t" >> users.tsv
count=$[count-1]
[ $count == 0 ] && break
	done
fi
		# if [ `grep -c "^$i$" usedports` -ne 0 ]; then continue; fi
		# if [ -e "users.tsv" ] && [ `grep -c -P "\-o\t$i\t" users.tsv` != 0 ]; then continue; fi
cat  users.tsv
cat users.tsv | uniq | tr '\t' ' ' | sudo xargs -l -P 10 ./Docker-BioInf-per-student.sh
# staff.tsv contains permament users.  User can be temporary excluded by symbol "#" in the beginning of row
cat staff.tsv
grep -h -v "^#" staff.tsv | uniq | tr '\t' ' ' | sudo xargs -l -P 10 ./Docker-BioInf-per-student.sh
cat ../user*/docker.txt > docker.txt

exit  # Not start later code automatically
# check users and space
cat /etc/passwd | awk -F':' '/home/ {print $1 "\t" "\t" $6 "\t" "\t" $NF}'
(sudo repquota -as | awk '(NR<6) {print}'; sudo repquota -as | awk '!($3~/K$/) && (NR>5) {print}' | sort -hr -k3)
docker images
docker ps -a
docker volume ls
docker system df
docker system df -v

ls .. | xargs -i docker top {} | awk '{print $1}' | sort | uniq -c

# Delete user*
ls .. | grep user
ls .. | grep user | xargs -l -P 10 docker stop
ls .. | grep user | xargs -l -P 10 docker rm
ls .. | grep user | xargs -l -P 10 docker volume rm
ls .. | grep user | xargs -l sudo userdel --remove
ls .. | grep user | wc -l

# Delete specific user
nuser="user300"
echo $nuser
docker top $nuser 
docker restart $nuser 
docker stop $nuser 
docker rm $nuser 
# docker volume rm $nuser
# sudo userdel --remove $nuser

# Stop all dockers
docker stop $(docker ps -a -q)
# Remove no active dockers
docker rm $(docker ps -a | grep "Exited" | awk '{print $1}')
# Remove all dockers
# docker rm $(docker ps -a -q)
# Remove all docker images
# docker rmi $(docker images -q)
# Remove docker images without correct names
# Old versions of Docker images
docker ps -a > dockers && docker ps -a  | awk '{print $2}' | grep -e "[0-9]" | sort | uniq | xargs -i grep {} dockers | awk '{print $2 "\t" $NF}'
# Actual versions
docker ps -a > dockers && docker ps -a  | awk '{print $2}' | grep -v "ID" | grep -v -e "[0-9]" | sort | uniq | xargs -i grep {} dockers | awk '{print $NF}'
# Remove not used Docker images
docker rmi $(docker images | grep "<none>" | awk '{print $3}') 
