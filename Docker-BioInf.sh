#!/usr/bin/bash

  # Settings can be edited in "Settings.ini"
  if [ -e "Settings.ini" ]; then source Settings.ini
  else
  tee Settings.ini << END
#for Google smtp_url="smtps://[user[:pass]@]smtp.gmail.com" https://ec.haxx.se/usingcurl/usingcurl-smtp#secure-mail-transfer
smtp_url="smtp://10.1.0.4" # smtp_url="smtp[s]://[user[:pass]@]host[:port]"
admin="admin@edu.eu"
if [ "\$base" == "" ] ; then base="serv1.edu.eu" ; fi # Required
alias4SSL="" # "" or "-d second.domain.edu -d test.domain.edu"
if [ "\$quota" == "" ] ; then quota="10G" ; fi  # HDD quota "200M" or "10G" or "1T"
if [ "\$ram" == "" ] ; then ram="4g" ; fi  # RAM quota "200m" or "10g"; should be a positive integer followed by the suffix m or g (short for megabytes, or gigabytes)
if [ "\$limit" == "" ] ; then limit="4.0" ; fi  # CPU quota "1.5" or "4.0"; should be a positive number
END
source Settings.ini
fi

  sudo apt update
  sudo apt upgrade -y --no-install-recommends
  sudo apt dist-upgrade -y --no-install-recommends
  sudo apt autoremove -y
  sudo apt autoclean -y
  if [ `docker images ghcr.io/zajakin/docker-bioinf | wc -l` -lt 2 ]; then
    sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf
  	sudo apt install docker-compose quota curl letsencrypt -y --no-install-recommends
  	sudo addgroup $USER docker
  	sudo systemctl enable docker
  	cat /etc/fstab | grep quota  # should be grpjquota=quota.group,usrjquota=quota.user,jqfmt=vfsv1  sudo nano /etc/fstab
  	sudo quotacheck -ugM -F vfsv1 /
  	sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="cgroup_enable=memory swapaccount=1"/' /etc/default/grub && sudo update-grub
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
  	glances="nicolargo/glances:alpine-latest-full"
  	# glances="nicolargo/glances:3.2.1-full"
  	docker pull $glances
  	if [ ! -e ./glances.conf ]; then wget --no-cache https://raw.githubusercontent.com/nicolargo/glances/develop/docker-compose/glances.conf -O glances.conf ; fi
  	docker run -d --name=monitoring --restart="always" --privileged -e GLANCES_OPT="-w" -v `pwd`/glances.conf:/glances/conf/glances.conf -v /etc/passwd:/etc/passwd:ro -v /var/run/docker.sock:/var/run/docker.sock:ro --pid host --network host $glances
  
  
  	sudo mkdir -p /data
  	sudo chmod +rx /data
  	sudo chown $USER /data
  	docker volume create --opt type=none --opt device=/data --opt o=bind,size=2TB --name data
  fi
  wget --no-cache https://github.com/zajakin/Docker-BioInf/raw/master/Docker-BioInf-per-student.sh -O Docker-BioInf-per-student.sh
  chmod +x Docker-BioInf-per-student.sh
  docker pull ghcr.io/zajakin/docker-bioinf
  # rm -r Docker-BioInf
  # mkdir Docker-BioInf
  # wget --no-cache https://github.com/zajakin/Docker-BioInf/raw/master/Dockerfile -O Docker-BioInf/Dockerfile
  # docker build -t docker-bioinf Docker-BioInf
  sudo certbot renew
  if [ ! -e "usedports" ] ; then echo 2 > usedports ; fi
  docker ps -a -q | xargs -l docker port  | awk -F ':' '{print substr($2, 1, length($2)-1)}' | sort | uniq > usedports
  
  # Add users and create Dockers
  # Download sample of file with users login and pass
  if [ ! -e "users.tsv" ]; then wget https://github.com/zajakin/Docker-BioInf/raw/master/sample_users.tsv -O users.tsv ; fi
  # Or generate automatically
  # rm users.tsv
  if [ ! -e "users.tsv" ]; then 
  	count=25
  	for i in {300..650}
  	do
  [ `grep -c "^$i$" usedports` != 0 ] && continue
  [ -e "users.tsv" ] && [ `grep -c -P "\-o\t$i\t" users.tsv` != 0 ] && continue
  echo -e "-u\tuser$i\t-b\t$base\t-o\t$i\t-q\t$quota\t-r\t$ram\t-l\t$limit\t-p\t$(cat /dev/urandom | tr -dc a-zA-Z0-9 | head -c8)\t-s\tbrnh\t-m\t#\t-c\t#" >> users.tsv
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
  #run command for users
  awk -F"\t" '!/^#/ {print $NF}' users.tsv | xargs -l1 bash -c 
  awk -F"\t" '!/^#/ {print $NF}' staff.tsv | xargs -l1 bash -c 
  # lazy unmount 
  awk -F"\t" '!/^#/ {print $NF}' staff.tsv | sed 's/fusermount -u/fusermount -zu/g' | xargs -l1 bash -c 
  # unmount all
  awk -F"\t" '!/^#/ {print $NF}' staff.tsv | sed 's/;.*/"/g' | xargs -l1 bash -c 
  # reload NGINX in staff's dockers (to update Letsencrypt certificate)
  awk '!/^#/ {print $2}' staff.tsv | xargs -i docker exec {} /usr/bin/supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart 6_nginx
  # update staff's dockers
  awk '!/^#/ {print $2}' staff.tsv | xargs -i docker exec {} /usr/bin/supervisorctl -c /etc/supervisor/conf.d/supervisord.conf start 7_update
  # Check the mounted folders for staff
  mount | awk -F '/' '/\/home/ {print $4}' > mounted.lst && awk '!/^#/ {print $2}' staff.tsv > staff.lst && grep -vxf mounted.lst staff.lst > mount.lst 
  awk -F"\t" '!/^#/ {print $NF}' staff.tsv | grep -f mount.lst | xargs -l1 bash -c 
  echo "  Mounted" && grep -f mounted.lst staff.lst && echo "  Not mounted" && grep -v -f mounted.lst staff.lst
  # check users and space
  cat /etc/passwd | awk -F':' '/home/ {print $1 "\t" "\t" $6 "\t" "\t" $NF}'
  (sudo repquota -as | awk '(NR<6) {print}'; sudo repquota -as | awk '!($3~/K$/) && (NR>5) {print}' | sort -hr -k3)
  docker ps -a --format '{{.Size}}  {{.Names}}' | sort -h
  docker images
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
  awk -F"\t" "/\t$nuser\t/ {print \$NF}" staff.tsv | xargs -l1 bash -c
  docker exec $nuser /usr/bin/supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart 5_sshd
  docker exec $nuser /usr/bin/supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart 6_nginx
  docker exec $nuser /etc/supervisor/conf.d/update.sh
  awk -F"\t" "/\t$nuser\t/ {print}" staff.tsv | tr '\t' ' ' | sudo xargs -l -P 10 ./Docker-BioInf-per-student.sh
  docker stop $nuser
  docker rm $nuser
  # docker volume rm $nuser
  # sudo userdel --remove $nuser
  awk '!/^#/ {print $2}' staff.tsv | xargs -i docker exec {} bash -c "apt-mark showmanual | grep -vFf /image_packages.txt > /etc/supervisor/conf.d/installed_packages.txt"
  
  # Stop all dockers
  docker stop $(docker ps -a -q)
  # Restart all dockers
  docker restart $(docker ps -a -q)
  # Remove no active dockers
  docker rm $(docker ps -a | grep "Exited" | awk '{print $1}')
  # Remove all dockers
  # docker rm $(docker ps -a -q)
  # Remove all docker images
  # docker rmi $(docker images -q)
  # Remove all Docker volumes
  # docker volume rm $(docker volume ls | awk '!/^DRIVER/{print $2}')
  # Old versions of Docker images
  docker ps -a | sed 's/".*"/CMD/g' > dockers && docker images -a --filter "dangling=true" -q | xargs -i grep "  {}  " dockers | awk '{print $4 " " $5 " " $6 "\t" $7 " " $8 " " $9 "\t" $2 "\t" $NF}'
  #Volumes
  (docker ps -a -q | xargs docker inspect -f '{{ .Mounts }}') | sed 's!/var/lib/docker/volumes/!!g' | sed 's!volume !!g'
  # Actual versions
  docker ps -a | sed 's/".*"/CMD/g' > dockers && docker images -a --format '{{.Repository}} {{.Tag}}' | awk '!/<none>/{print $1}' | xargs -i grep "{}" dockers | awk '{print $4 " " $5 " " $6 "\t" $7 " " $8 " " $9 "\t" $2 "\t" $NF}'
  # Remove not used Docker images
  docker rmi $(docker images -q)
  
  function lastVisit {
    docker ps -a > dockers
    for u in $(basename -a $(ls -d /home/*)); do
      lastb=0
      [ -e /home/$u/$u/.bash_history ] && lastb=`stat -c %Y /home/$u/$u/.bash_history`
      lastw=0
      [ $(grep -c -v ' - - ' /home/$u/log/nginx-access.log) -gt 0 ] && lastw=`grep -av ' - - ' /home/$u/log/nginx-access.log | awk 'END{gsub("\[",""); print $4}' | awk '{gsub("[/:]",FS,$0); print mktime(sprintf("%d %d %d %d %d %d",$3,(((index("JanFebMarAprMayJunJulAugSepOctNovDec",$2)-1)/3)+1),$1,$4,$5,$6) )}'`
      last=$lastb
      [ $lastb -lt $lastw ] && last=$lastw
      echo -e "`date +'%Y-%m-%d' --date=@$last`\t`date +'%Y-%m-%d' --date=@$lastb`\t`date +'%Y-%m-%d' --date=@$lastw`\t$u\t`awk "/$u\$/{print \\$4 \\$5 \"_\" \\$7 \\$8 \\$9}" dockers`\t`cat /home/$u/setup/installed_packages.txt | tr '\n' ' '`"
    done
  }
  docker ps -a  --format '{{.Names}}' > dockers && awk '!/^#/ {print $2}' staff.tsv | grep -v -f dockers
  lastVisit | sort > users_$(date +'%Y-%m-%d').txt
  cat users_$(date +'%Y-%m-%d').txt
