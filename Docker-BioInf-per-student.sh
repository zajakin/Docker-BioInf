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
source Settings.ini
echo "nuser=$nuser base=$base portD=$portD quota=$quota pass=$pass start=$start email=$email"
if [ "$nuser" == "" ] ; then
	echo "Error! No user name"
	read -p "Press enter to continue"
	exit
fi
if [ `docker ps -a | grep -c ${nuser}$` -ne 0 ] ; then 
	echo "Error! User '$nuser' already have Docker container"
	exit
fi
if [ "$base" == "" ] ; then exit; fi
if [ "$portD" == "" ] ; then portD=$[$(sort -nur usedports | head -n 1)+1]; fi
echo $portD >> usedports
if [ "$quota" == "" ] ; then quota="10G" ; fi
if [ "$pass" == "" ] ; then pass=$(cat /dev/urandom | tr -dc a-zA-Z0-9 | head -c8) ; fi
if [ "$start" == "" ] ; then start="h" ; fi

sudo useradd -g docker -N -s /bin/bash --create-home $nuser
sudo setquota -u $nuser $quota $quota 0 0 /
cd /home/$nuser
echo $admin | sudo tee admin > /dev/null
echo $smtp_url | sudo tee smtp_url > /dev/null
echo $nuser | sudo tee nuser > /dev/null
echo $base | sudo tee base > /dev/null
echo $portD | sudo tee portD > /dev/null
echo $quota | sudo tee quota > /dev/null
echo $pass | sudo tee pass > /dev/null
echo $start | sudo tee start > /dev/null
echo $email | sudo tee email > /dev/null

sudo su $nuser
admin=`cat admin`
smtp_url=`cat smtp_url`
nuser=`cat nuser`
uid=$(id -u $nuser)
gid=$(id -g $nuser)
base=`cat base`
portD=`cat portD`
quota=`cat quota`
pass=`cat pass`
start=`cat start`
email=`cat email`
URLp="https://${base}:${portD}0"
URLs="${URLp}/s"
URLn="https://${base}:${portD}1"
URLb="${URLp}/b"
URLr="${URLp}/r"
URLj="${URLp}/j"
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
docker volume create --opt type=none --opt device=/home/$nuser/$nuser --opt o=bind,size=${quota}B,uid=$uid --name $nuser > /dev/null
pushd /home/$nuser/setup  > /dev/null

key=/cert/live/$base/privkey.pem
cert=/cert/live/$base/fullchain.pem
dhparam=/cert/dhparam.pem

tee update.sh << END > /dev/null
#!/bin/bash
for pic in supervisor rstudio jupyter noVNC shellinabox
do
	wget https://github.com/zajakin/Docker-BioInf/raw/master/\${pic}.png -O /usr/share/novnc/\${pic}.png
	ln -s /usr/share/novnc/\${pic}.png /usr/lib/python3/dist-packages/supervisor/ui/\${pic}.png
done
echo '<html><body><center>
<a href="$URLs"><img src="${URLp}/supervisor.png" /><br /><h1>Supervisor</h1></a><br />
<table><tr align="center" valign="bottom">
<td><a href="${URLr}"><img src="${URLp}/rstudio.png" /><br /><h1>R-Studio</h1></a></td>
<td><a href="${URLj}"><img src="${URLp}/jupyter.png" /><br /><h1>Jupyter notebook</h1></a></td>
</tr><tr align="center" valign="bottom">
<td><a href="${URLn}/vnc.html"><img src="${URLp}/noVNC.png" /><br /><h1>noVNC</h1></a></td>
<td><a href="${URLb}"><img src="${URLp}/shellinabox.png" /><br /><h1>Shell in a box</h1></a></td>
</tr></table></center></body></html>' > /usr/share/novnc/index.html
sed -i 's@^<table>.*</table>@@' /usr/lib/python3/dist-packages/supervisor/ui/status.html
cp /usr/lib/python3/dist-packages/supervisor/ui/status.html /usr/lib/python3/dist-packages/supervisor/ui/status.dist
sed -i 's@  <div class="push">@<table><tr align="center"><td><a href="${URLp}/home/"><h1>Home directory</h1></a></td><td><a href="http://${base}:61208"><h1>Tasks monitoring</h1></a></td></tr><tr align="center" valign="bottom"><td><a href="${URLr}"><img src="${URLp}/rstudio.png" /><br /><h1>R-Studio</h1></a></td><td><a href="${URLj}"><img src="${URLp}/jupyter.png" /><br /><h1>Jupyter notebook</h1></a></td></tr><tr align="center" valign="bottom"><td><a href="${URLn}/vnc.html"><img src="${URLp}/noVNC.png" /><br /><h1>noVNC</h1></a></td><td><a href="${URLb}"><img src="${URLp}/shellinabox.png" /><br /><h1>Shell in a box</h1></a></td></tr></table>\
  <div class="push">@' /usr/lib/python3/dist-packages/supervisor/ui/status.html
if [ ! -e "/etc/nginx/nginx.dist" ] ; then mv /etc/nginx/nginx.conf /etc/nginx/nginx.dist ; fi
mkdir /var/log/nginx
ln -s /home/$nuser /usr/share/novnc/home
echo 'daemon off;
user www-data;
worker_processes 2;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 2000;
        # multi_accept on;
}
http {
	map \$http_upgrade \$connection_upgrade {
		default upgrade;
		""      close;
	}
	upstream vnc_proxy {
		server 127.0.0.1:5900;
	}
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	include /etc/nginx/mime.types;
	default_type application/octet-stream;
	ssl_session_timeout  1d;
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv2 SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;
	ssl_ciphers  ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP;
	ssl_certificate        $cert;
	ssl_certificate_key    $key;
	ssl_dhparam            $dhparam;
	ssl_session_cache shared:SSL:50m;
	ssl_stapling on;
	ssl_stapling_verify on;
	add_header Strict-Transport-Security max-age=15768000;
	access_log /var/log/nginx-access.log;
	error_log /var/log/nginx-error.log error;
	server {
		listen 443 ssl http2;
		root /usr/share/novnc;
		rewrite ^/\$ $URLs/ permanent;
		rewrite ^/s\$ $URLs/ permanent; 
		location /s/ {
			rewrite ^/s/(.*)\$ /\$1 break;
			proxy_pass http://localhost:9001;
			proxy_redirect http://localhost:9001/ $URLs/;
			proxy_http_version 1.1;
			proxy_buffering off;
		}
		rewrite ^/home\$ $URLp/home/ permanent; 
		location /home/ {
			autoindex on;
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
			# rewrite ^/j/(.*)\$ /\$1 break;
			proxy_pass http://localhost:8888 ;
			proxy_redirect http://localhost:8888/j ${URLj} ;
			proxy_set_header X-Real-IP \$remote_addr;
			proxy_set_header Host \$host:3000;
			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			proxy_http_version 1.1;
			proxy_set_header Upgrade \$http_upgrade;
			proxy_set_header Connection \$connection_upgrade;
			proxy_read_timeout 20d;
			proxy_buffering off;
		}
		location ~* /j/(api/kernels/[^/]+/(channels|iopub|shell|stdin)|terminals/websocket)/? {
			proxy_pass http://localhost:8888;
			proxy_set_header X-Real-IP \$remote_addr;
			proxy_set_header Host \$host:3000;
			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			proxy_set_header X-NginX-Proxy true;
			proxy_http_version 1.1;
			proxy_set_header Upgrade "websocket";
			proxy_set_header Connection "upgrade";
			proxy_read_timeout 20d;
			proxy_buffering off;
		}
		# rewrite ^/n\$ $URLn/ permanent; 
		# location /n/ {
		# 	rewrite ^/n/(.*)\$ /\$1 break;
		# 	proxy_pass https://localhost:5900;
		# 	proxy_redirect https://localhost:5900/ $URLn/;
		# 	proxy_http_version 1.1;
		# 	proxy_set_header Upgrade \$http_upgrade;
		# 	proxy_set_header Connection \$connection_upgrade;
		# 	proxy_read_timeout 20d;
		# 	proxy_buffering off;
		# }
		# rewrite ^/websockify\$ $URLn/websockify permanent; 
		# location /n/websockify {
		# 	proxy_http_version 1.1;
		# 	proxy_pass https://vnc_proxy;
		# 	proxy_set_header Upgrade \$http_upgrade;
		# 	proxy_set_header Connection "upgrade";
		# 	proxy_read_timeout 300s;
		# 	proxy_buffering off;
		# }
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
echo -e "c.NotebookApp.password = u'\$PASS'\nc.JupyterHub.bind_url = 'http://0.0.0.0:8888'\nc.NotebookApp.base_url = '/j'" | /sbin/runuser -u $nuser -- tee /home/$nuser/.jupyter/jupyter_notebook_config.py
END

tee setup.sh << END > /dev/null
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

echo -e "[supervisord]
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
port=0.0.0.0:9001
username=$nuser
password=$pass
" > supervisord.conf

echo -e '[program:setup]
command=/bin/bash -c /etc/supervisor/conf.d/setup.sh
stdout_logfile=/var/log/setup.log
autostart=true
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
' > setup.conf

# --user $uid:$gid -v /var/run/docker.sock:/var/run/docker.sock --net dockers-net --ip=$base -p ${portD}4:4200 -p ${portD}7:8787 -p ${portD}3:8888
docker run -d --name=$nuser -p ${portD}0:443 -p ${portD}1:5900 -p ${portD}2:22 --workdir /home/$nuser \
	-v $nuser:/home/$nuser -v data:/data -v /home/$nuser/setup:/etc/supervisor/conf.d -v cert:/cert:ro \
	-v /home/$nuser/log:/var/log --restart always docker-bioinf

echo -e "[program:1_novnc_1_novnc]
command=websockify --web=/usr/share/novnc/ --key=$key --cert=$cert 5900 localhost:5901
stdout_logfile=/var/log/novnc.log
autostart=$startn
autorestart=true
user=root
stopsignal=KILL
numprocs=1
redirect_stderr=true
" > novnc.conf

echo -e "[program:1_novnc_2_vnc]
command=/sbin/runuser -u $nuser -- /usr/bin/vncserver :1 -fg -localhost yes -depth 24 -geometry 1920x1080 -port 5901 -SecurityTypes VncAuth -PasswordFile /home/$nuser/.vnc/passwd -xstartup /usr/bin/startlxde
stdout_logfile=/var/log/vnc.log
autostart=$startn
autorestart=true
user=root
stopsignal=QUIT
numprocs=1
redirect_stderr=true
" > vnc.conf
 
echo -e '[program:1_novnc_3_remove_X_win_start_lock]
command=/bin/bash -c "rm -f /tmp/.X1-lock; rm -fr /tmp/.X11-unix; pkill Xtigervnc; pkill mem-cached; pkill websockify; pkill ssh-agent"
stdout_logfile=/var/log/remove_X_win_start_lock.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
' > remove_X_win_start_lock.conf

echo -e "[program:2_shellinaboxd]
command=/usr/bin/shellinaboxd -t --css /etc/shellinabox/options-available/00_White\ On\ Black.css
stdout_logfile=/var/log/shellinaboxd.log
autostart=$startb
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
" > shellinaboxd.conf

echo -e "[program:3_RStudio]
command=/usr/lib/rstudio-server/bin/rserver --server-daemonize 0
stdout_logfile=/var/log/rserver.log
autostart=$startr
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
" > RStudio.conf
#  --certfile=$cert --keyfile=$key
echo -e "[program:4_jupyter_notebook]
command=/sbin/runuser -u $nuser -- jupyter notebook -y --ip=0.0.0.0 --no-browser --config=/home/$nuser/.jupyter/jupyter_notebook_config.py
stdout_logfile=/var/log/jupyter_notebook.log
directory=/home/$nuser
autostart=$startj
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
" > jupyter_notebook.conf

echo -e "[program:5_sshd]
command=/usr/sbin/sshd -D
stdout_logfile=/var/log/sshd.log
autostart=$starth
autorestart=true
user=root
stopsignal=KILL
numprocs=1
redirect_stderr=true
" > sshd.conf

echo -e '[program:6_nginx]
command=/usr/sbin/nginx
stdout_logfile=/var/log/nginx.log
autostart=true
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
' > nginx.conf

echo -e '[program:7_update]
command=/etc/supervisor/conf.d/update.sh
stdout_logfile=/var/log/update.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
' > update.conf

echo -e '[program:8_restart_server]
command=/usr/bin/pkill supervisord
stdout_logfile=/var/log/restart_server.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
' > restart_server.conf

chmod +r *
sleep 10s
docker exec -it $nuser pkill supervisord
popd > /dev/null
echo -e "User:\t$nuser\tPassword:\t$pass\tAddress:\t$URLp" > docker.txt
tee mail.txt << END
From: <$admin>
CC: <$admin>
To: <$email>
Subject: Access to Docker container
 
Hi!
 
Your Docker container is ready.
User: $nuser
Password: $pass
 
Addresses:
1) Dashboard - https://${base}:${portD}0
2) ssh -X ${nuser}@${base} -p ${portD}2
3) RStudio (should be started in Dashboard) - $URLr
4) Jupier notebook (should be started in Dashboard) - $URLj 
5) ShellInABox (should be started in Dashboard) - $URLb 
6) VNC (should be started in Dashboard) - $URLn/vnc.html
 
If you can not access to Docker container from home:
1) Check your external IP ( for example on https://www.whatsmyip.org )
2) Send this IP to $admin to adjust firewall.
 
.
END

if [ ! "$email" == "" ] ; then
	/usr/bin/curl $smtp_url --mail-from $admin --mail-rcpt $email --upload-file mail.txt
fi
exit # exit from su
cd ~
