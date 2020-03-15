#!/usr/bin/bash
while getopts ":u:b:o:q:p:s:m:" opt; do
  case $opt in
    u) nuser="$OPTARG"
    ;;
    b) base="$OPTARG"
    ;;
    o) portD="$OPTARG"
    ;;
    q) quota="$OPTARG"
    ;;
    p) pass="$OPTARG"
    ;;
    s) start="$OPTARG"
    ;;
    m) email="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# nuser="user00";  base="serv1.edu.eu";  portD="2020";	quota=="2T";	pass="pass1200"; email="user00@gmail.com"
echo "nuser=$nuser base=$base portD=$portD quota=$quota pass=$pass email=$email"
if [ "$nuser" == "" ] ; then
	read -p "Error! No user name
	Press enter to continue"
	exit
fi
if [ `cat /etc/passwd | grep -c "^${nuser}:"` -ne 0 ] ; then 
	read -p "Error! User '$nuser' already exist
	Press enter to continue"
	exit
fi
if [ "$base" == "" ] ; then exit; fi
if [ "$portD" == "" ] ; then portD=$[$(sort -nur usedports | head -n 1)+1]; fi
echo $portD >> usedports
if [ "$quota" == "" ] ; then quota="2T" ; fi
if [ "$pass" == "" ] ; then pass=$(cat /dev/urandom | tr -dc a-zA-Z0-9 | head -c8) ; fi
if [ "$start" == "" ] ; then start="h" ; fi

sudo useradd -g docker -N -s /bin/bash --create-home $nuser
sudo quota -vs $nuser
sudo setquota -u $nuser $quota $quota 0 0 /
cd /home/$nuser
echo $nuser | sudo tee nuser
echo $base | sudo tee base
echo $portD | sudo tee portD
echo $quota | sudo tee quota
echo $pass | sudo tee pass
echo $start | sudo tee start

sudo su $nuser
nuser=`cat nuser`
uid=$(id -u $nuser)
gid=$(id -g $nuser)
base=`cat base`
portD=`cat portD`
quota=`cat quota`
pass=`cat pass`
start=`cat start`
IP="${base}:${portD}"
URLs="https://${IP}0/s/"
URLn="https://${IP}1"
URLb="https://${IP}0/b/"
URLr="https://${IP}0/r/"
URLj="https://${IP}3"
for st in r j n b h
do
	stv=start${st}
	eval ${stv}="false"
	if [ "$(echo $start | grep -c $st)" -ne "0" ]
	then declare ${stv}="true"
	fi
done

rm -rf /home/$nuser/setup /home/$nuser/log
mkdir -p /home/$nuser/setup /home/$nuser/$nuser/ /home/$nuser/log/supervisor
docker volume create --opt type=none --opt device=/home/$nuser/$nuser --opt o=bind,size=${quota}B,uid=$uid --name $nuser
docker volume inspect $nuser
pushd /home/$nuser/setup
key=/etc/supervisor/conf.d/self.key
cert=/etc/supervisor/conf.d/self.pem
openssl req -x509 -nodes -newkey rsa:2048 -keyout self.key -out self.pem -batch -days 3650
# cat self.key self.pem > certificate.pem

tee update.sh << END
#!/bin/bash
for pic in supervisor rstudio jupyter noVNC shellinabox
do
	wget https://github.com/zajakin/Docker-BioInf/raw/master/\${pic}.png -O /usr/share/novnc/\${pic}.png
	ln -s /usr/share/novnc/\${pic}.png /usr/lib/python3/dist-packages/supervisor/ui/\${pic}.png
done
echo '<html><body><center>
<a href="$URLs"><img src="${URLn}/supervisor.png" /><br /><h1>Supervisor</h1></a><br />
<table><tr align="center" valign="bottom">
<td><a href="${URLr}"><img src="${URLn}/rstudio.png" /><br /><h1>R-Studio</h1></a></td>
<td><a href="${URLj}"><img src="${URLn}/jupyter.png" /><br /><h1>Jupyter notebook</h1></a></td>
</tr><tr align="center" valign="bottom">
<td><a href="${URLn}/vnc.html"><img src="${URLn}/noVNC.png" /><br /><h1>noVNC</h1></a></td>
<td><a href="${URLb}"><img src="${URLn}/shellinabox.png" /><br /><h1>Shell in a box</h1></a></td>
</tr></table></center></body></html>' > /usr/share/novnc/index.html
sed -i 's@^<table>.*</table>@@' /usr/lib/python3/dist-packages/supervisor/ui/status.html
cp /usr/lib/python3/dist-packages/supervisor/ui/status.html /usr/lib/python3/dist-packages/supervisor/ui/status.dist
sed -i 's@  <div class="push">@<table><tr align="center" valign="bottom"><td><a href="${URLr}"><img src="${URLs}/rstudio.png" /><br /><h1>R-Studio</h1></a></td><td><a href="${URLj}"><img src="${URLs}/jupyter.png" /><br /><h1>Jupyter notebook</h1></a></td></tr><tr align="center" valign="bottom"><td><a href="${URLn}/vnc.html"><img src="${URLs}/noVNC.png" /><br /><h1>noVNC</h1></a></td><td><a href="${URLb}"><img src="${URLs}/shellinabox.png" /><br /><h1>Shell in a box</h1></a></td></tr></table>\
  <div class="push">@' /usr/lib/python3/dist-packages/supervisor/ui/status.html
if [ ! -e "/etc/nginx/nginx.dist" ] ; then mv /etc/nginx/nginx.conf /etc/nginx/nginx.dist ; fi
mkdir /var/log/nginx
echo 'daemon off;
user www-data;
worker_processes 1;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 2;
        # multi_accept on;
}
http {
  map \$http_upgrade \$connection_upgrade {
      default upgrade;
      ""      close;
    }
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	include /etc/nginx/mime.types;
	default_type application/octet-stream;
    ssl_session_timeout  5m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv2 SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;
    ssl_ciphers  ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP;
    ssl_certificate        $cert;
    ssl_certificate_key    $key;
    access_log /var/log/nginx-access.log;
    error_log /var/log/nginx-error.log error;
  server {
    listen 443 ssl;
    server_name $base;
    rewrite ^/\$ $URLs/ permanent; 
    location / {
      proxy_pass http://localhost:80;
      proxy_redirect http://localhost:80/ $URLs/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_read_timeout 20d;
      proxy_buffering off;
    }
    rewrite ^/r\$ $URLr/ permanent; 
    location /r/ {
      rewrite ^/r/(.*)\$ /\$1 break;
      proxy_pass http://localhost:8787;
      proxy_redirect http://localhost:8787/ $URLr/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_read_timeout 20d;
      proxy_buffering off;
    }
    rewrite ^/j\$ $URLj/ permanent; 
    location /j/ {
      rewrite ^/j/(.*)\$ /\$1 break;
      proxy_pass https://localhost:8888;
      proxy_redirect https://localhost:8888/ $URLj/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_read_timeout 20d;
      proxy_buffering off;
    }
    rewrite ^/n\$ $URLn/ permanent; 
    rewrite ^/websockify\$ $URLn/websockify permanent; 
    location /n/ {
      rewrite ^/n/(.*)\$ /\$1 break;
      proxy_pass https://localhost:5900;
      proxy_redirect https://localhost:5900/ $URLn/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_read_timeout 20d;
      proxy_buffering off;
    }
    rewrite ^/b\$ $URLb/ permanent; 
    location /b/ {
      rewrite ^/b/(.*)\$ /\$1 break;
      proxy_pass http://localhost:4200;
      proxy_redirect http://localhost:4200/ $URLb/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_read_timeout 20d;
      proxy_buffering off;
    }
  }
}' > /etc/nginx/nginx.conf
# ln -s /etc/nginx/sites-available/shiny-server /etc/nginx/sites-enabled/shiny-server
env DEBIAN_FRONTEND=noninteractive apt-get update -y
env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends
env DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends
env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
env DEBIAN_FRONTEND=noninteractive apt-get autoclean -y
env DEBIAN_FRONTEND=noninteractive apt-get clean -y
OLDCONF=\$(dpkg -l|grep "^rc"|awk '{print \$2}')
env DEBIAN_FRONTEND=noninteractive apt-get purge -y \$OLDCONF
rm -rf /home/*/.local/share/Trash/*/** &> /dev/null
rm -rf /root/.local/share/Trash/*/** &> /dev/null
/sbin/runuser -u $nuser -- jupyter notebook --generate-config -y
PASS=\$(python3 -c "from notebook.auth import passwd; print(passwd('$pass'))")
echo "c.NotebookApp.password = u'\$PASS'" | /sbin/runuser -u $nuser -- tee /home/$nuser/.jupyter/jupyter_notebook_config.py
END

tee setup.sh << END
#!/bin/bash
if [ ! -e /etc/supervisor/conf.d/setup.done ]; then
	groupadd -g $gid $nuser
	useradd -u $uid -g $gid -G sudo -d /home/$nuser -s /bin/bash -m $nuser
	echo "$nuser:$pass" | chpasswd
	mkdir -p /home/$nuser/.vnc
	echo $pass | vncpasswd -f > /home/$nuser/.vnc/passwd
	cp -r -n /etc/skel/.[!.]* /home/$nuser
	chown -R $nuser /home/$nuser
	/etc/supervisor/conf.d/update.sh
	mv /etc/supervisor/conf.d/setup.conf /etc/supervisor/conf.d/setup.done
fi
END
chmod +rx *.sh

tee supervisord.conf << END
[supervisord]
user=root
nodaemon=true
redirect_stderr=true

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock
username=$nuser
password=$pass

[unix_http_server]
file = /tmp/supervisor.sock
chmod = 0777
chown= nobody:nogroup
username=$nuser
password=$pass

[inet_http_server]
port=0.0.0.0:80
username=$nuser
password=$pass
END

tee setup.conf << END
[program:setup]
command=/bin/bash -c /etc/supervisor/conf.d/setup.sh
stdout_logfile=/var/log/setup.log
autostart=true
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

# --user $uid:$gid -v /var/run/docker.sock:/var/run/docker.sock --net dockers-net --ip=$base -p ${portD}4:4200 -p ${portD}7:8787
docker run -d --name=$nuser -v $nuser:/home/$nuser -v data:/data -v /home/$nuser/setup:/etc/supervisor/conf.d \
		-p ${portD}0:443 -p ${portD}1:5900 -p ${portD}2:22 -p ${portD}3:8888 \
		--workdir /home/$nuser -v /home/$nuser/log:/var/log --restart always docker-bioinf

tee novnc.conf << END
[program:1_novnc_1_novnc]
command=websockify --web=/usr/share/novnc/ --key=$key --cert=$cert 5900 localhost:5901
stdout_logfile=/var/log/novnc.log
autostart=$startn
autorestart=true
user=root
stopsignal=KILL
numprocs=1
redirect_stderr=true
END
# LD_PRELOAD=/usr/lib/websockify/rebind.so exec python -m websockify --key=$key --cert=$cert 443 --  /usr/bin/vncserver :1 -fg -localhost yes -depth 24 -geometry 1920x1080 -port 5901 -SecurityTypes VncAuth -PasswordFile /home/$nuser/.vnc/passwd -xstartup /usr/bin/startlxde
tee vnc.conf << END
[program:1_novnc_2_vnc]
command=/sbin/runuser -u $nuser -- /usr/bin/vncserver :1 -fg -localhost yes -depth 24 -geometry 1920x1080 -port 5901 -SecurityTypes VncAuth -PasswordFile /home/$nuser/.vnc/passwd -xstartup /usr/bin/startlxde
stdout_logfile=/var/log/vnc.log
autostart=$startn
autorestart=true
user=root
stopsignal=QUIT
numprocs=1
redirect_stderr=true
END
 
tee remove_X_win_start_lock.conf << END
[program:1_novnc_3_remove_X_win_start_lock]
command=/bin/bash -c "rm -f /tmp/.X1-lock; rm -fr /tmp/.X11-unix; pkill Xtigervnc; pkill mem-cached; pkill websockify; pkill ssh-agent"
stdout_logfile=/var/log/remove_X_win_start_lock.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
END
#  --cert=/etc/supervisor/conf.d
tee shellinaboxd.conf << END
[program:2_shellinaboxd]
command=/usr/bin/shellinaboxd -t --css /etc/shellinabox/options-available/00_White\ On\ Black.css
stdout_logfile=/var/log/shellinaboxd.log
autostart=$startb
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
END

tee RStudio.conf << END
[program:3_RStudio]
command=/usr/lib/rstudio-server/bin/rserver --server-daemonize 0
stdout_logfile=/var/log/rserver.log
autostart=$startr
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
END

tee jupyter_notebook.conf << END
[program:4_jupyter_notebook]
command=/sbin/runuser -u $nuser -- jupyter notebook -y --no-browser --ip=0.0.0.0 --certfile=$cert --keyfile=$key --config=/home/$nuser/.jupyter/jupyter_notebook_config.py
stdout_logfile=/var/log/jupyter_notebook.log
directory=/home/$nuser
autostart=$startj
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
END

tee sshd.conf << END
[program:5_sshd]
command=/usr/sbin/sshd -D
stdout_logfile=/var/log/sshd.log
autostart=$starth
autorestart=true
user=root
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

tee nginx.conf << END
[program:6_nginx]
command=/usr/sbin/nginx
stdout_logfile=/var/log/nginx.log
autostart=true
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
END

tee update.conf << END
[program:7_update]
command=/etc/supervisor/conf.d/update.sh
stdout_logfile=/var/log/update.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

tee restart_server.conf << END
[program:8_restart_server]
command=/usr/bin/pkill supervisord
stdout_logfile=/var/log/restart_server.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

# [rpcinterface:supervisor]
# supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
# [program:tmux]
# command=/sbin/runuser -u $USER --pty -- /usr/bin/tmux
# stdout_logfile=/var/log/tmux.log
# autostart=true
# autorestart=true
# stopsignal=KILL
# numprocs=1

chmod +r *
sleep 10s
docker restart $nuser
# docker exec -it $nuser pkill supervisord
# docker exec -it $nuser pkill Xtigervnc && pkill mem-cached && pkill ssh-agent
popd
echo "Docker ready. User: $nuser Password: $pass Address: $URLs" > docker.txt
exit # exit from su
# if [ "$email" -ne "" ] ; then
# 	mutt  -s "Docker ready" -a /opt/backup.sql $email < docker.txt
# fi
cd ~
