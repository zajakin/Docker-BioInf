#!/usr/bin/bash
while getopts ":u:b:o:q:p:m:" opt; do
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
    m) email="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# nuser="";  base="";  portD="1003";	quota=="";	pass=""; email=""
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
if [ ! -e "usedports" ] ; then echo 2000 > usedports ; fi
if [ "$portD" == "" ] ; then portD=$[$(sort -nur usedports | head -n 1)+1]; fi
echo $portD | tee -a usedports
if [ "$quota" == "" ] ; then quota="2T" ; fi
if [ "$pass" == "" ] ; then pass=$(cat /dev/urandom | tr -dc a-zA-Z0-9 | head -c8) ; fi

sudo useradd -g docker -N -s /bin/bash --create-home $nuser
sudo quota -vs $nuser
sudo setquota -u $nuser $quota $quota 0 0 /
cd /home/$nuser
echo $base | sudo tee base
echo $portD | sudo tee portD
echo $quota | sudo tee quota
echo $pass | sudo tee pass

sudo su $nuser
nuser=$USER
uid=$(id -u)
gid=$(id -g)
base=`cat base`
portD=`cat portD`
quota=`cat quota`
pass=`cat pass`
IP="${base}:${portD}"
URLsupervisor="http://${IP}0"
URLnoVNC="https://${IP}1"
URLshellinabox="https://${IP}4"
URLrstudio="http://${IP}7"
URLjupiter="https://${IP}8"

rm -rf /home/$nuser/setup /home/$nuser/log
mkdir -p /home/$nuser/setup /home/$nuser/$nuser/ /home/$nuser/log/supervisor
docker volume create --opt type=none --opt device=/home/$nuser/$nuser --opt o=bind,size=${quota}B,uid=$uid --name $nuser
docker volume inspect $nuser
pushd /home/$nuser/setup
openssl req -x509 -nodes -newkey rsa:2048 -keyout self.key -out self.pem -batch -days 3650
cat self.key self.pem > certificate.pem

tee update.sh << END
#!/bin/bash
wget https://www.home-assistant.io/images/screenshots/supervisor.png -O /usr/share/novnc/supervisor.png
wget https://d33wubrfki0l68.cloudfront.net/6942646e91236f9d6766b0bfdce65fc2bbcf4d03/1e04f/assets/img/rstudio-desktop-screen.png -O /usr/share/novnc/rstudio.png
wget https://jupyter.org/assets/labpreview.png -O /usr/share/novnc/jupyter.png
wget https://i.ytimg.com/vi/b5tBNdncDNk/noVNC.jpg -O /usr/share/novnc/noVNC.png
wget https://linoxide.com/wp-content/uploads/2014/03/shellinabox_chrome_right_click.png -O /usr/share/novnc/shellinabox.png
ln -s /usr/share/novnc/supervisor.png /usr/lib/python3/dist-packages/supervisor/ui/supervisor.png
ln -s /usr/share/novnc/rstudio.png /usr/lib/python3/dist-packages/supervisor/ui/rstudio.png
ln -s /usr/share/novnc/jupyter.png /usr/lib/python3/dist-packages/supervisor/ui/jupyter.png
ln -s /usr/share/novnc/noVNC.png /usr/lib/python3/dist-packages/supervisor/ui/noVNC.png
ln -s /usr/share/novnc/shellinabox.png /usr/lib/python3/dist-packages/supervisor/ui/shellinabox.png
echo '<html><body><center>
<a href="$URLsupervisor"><img src="${URLnoVNC}/supervisor.png" /><br /><h1>Supervisor</h1></a><br />
<table><tr align="center" valign="bottom">
<td><a href="${URLrstudio}"><img src="${URLnoVNC}/rstudio.png" width="300" height="200" /><br /><h1>R-Studio</h1></a></td>
<td><a href="${URLjupiter}"><img src="${URLnoVNC}/jupyter.png" width="300" height="200" /><br /><h1>Jupyter notebook</h1></a></td>
</tr><tr align="center" valign="bottom">
<td><a href="${URLnoVNC}/vnc.html"><img src="${URLnoVNC}/noVNC.jpg" width="300" height="200" /><br /><h1>noVNC</h1></a></td>
<td><a href="${URLshellinabox}"><img src="${URLnoVNC}/shellinabox.png" width="300" height="200" /><br /><h1>Shell in a box</h1></a></td>
</tr></table></center></body></html>' > /usr/share/novnc/index.html
sed -i 's@^<table>.*@@' /usr/lib/python3/dist-packages/supervisor/ui/status.html
cp /usr/lib/python3/dist-packages/supervisor/ui/status.html /usr/lib/python3/dist-packages/supervisor/ui/status.dist
sed -i 's@  <div class="push">@<table><table><tr align="center" valign="bottom">
<td><a href="${URLrstudio}"><img src="${URLsupervisor}/rstudio.png" width="300" height="200" /><br /><h1>R-Studio</h1></a></td>
<td><a href="${URLjupiter}"><img src="${URLsupervisor}/jupyter.png" width="300" height="200" /><br /><h1>Jupyter notebook</h1></a></td>
</tr><tr align="center" valign="bottom">
<td><a href="${URLnoVNC}/vnc.html"><img src="${URLsupervisor}/noVNC.jpg" width="300" height="200" /><br /><h1>noVNC</h1></a></td>
<td><a href="${URLshellinabox}"><img src="${URLsupervisor}/shellinabox.png" width="300" height="200" /><br /><h1>Shell in a box</h1></a></td>
</tr></table>
<div class="push">@' /usr/lib/python3/dist-packages/supervisor/ui/status.html
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
journalctl --flush
journalctl --disk-usage
journalctl --vacuum-size=1000
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

# --user $uid:$gid -v /var/run/docker.sock:/var/run/docker.sock  --net dockers-net --ip=$base
docker run -d --name=$nuser -v $nuser:/home/$nuser -v data:/data -v /home/$nuser/setup:/etc/supervisor/conf.d \
		-p ${portD}0:80 -p ${portD}1:443 -p ${portD}2:22 -p ${portD}4:4200 -p ${portD}7:8787 -p ${portD}8:8888 \
		--workdir /home/$nuser -v /home/$nuser/log:/var/log --restart always Docker-BioInf

tee novnc.conf << END
[program:1_novnc_1_novnc]
command=websockify --web=/usr/share/novnc/ --key=/etc/supervisor/conf.d/self.key --cert=/etc/supervisor/conf.d/self.pem 443 localhost:5901
stdout_logfile=/var/log/novnc.log
autostart=false
autorestart=true
user=root
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

tee vnc.conf << END
[program:1_novnc_2_vnc]
command=/sbin/runuser -u $nuser -- /usr/bin/vncserver :1 -fg -localhost yes -depth 24 -geometry 1920x1080 -port 5901 -SecurityTypes VncAuth -PasswordFile /home/$nuser/.vnc/passwd -xstartup /usr/bin/startlxde
stdout_logfile=/var/log/vnc.log
autostart=false
autorestart=true
user=root
stopsignal=QUIT
numprocs=1
redirect_stderr=true
END
 
tee remove_X_win_start_lock.conf << END
[program:1_novnc_3_remove_X_win_start_lock]
command=/bin/bash -c "pkill Xtigervnc && pkill mem-cached && pkill websockify && pkill ssh-agent && rm -f /tmp/.X1-lock && rm -fr /tmp/.X11-unix"
stdout_logfile=/var/log/remove_X_win_start_lock.log
autostart=false
autorestart=false
user=root
startsecs=0
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

tee shellinaboxd.conf << END
[program:2_shellinaboxd]
command=/usr/bin/shellinaboxd --cert=/etc/supervisor/conf.d --css /etc/shellinabox/options-available/00_White\ On\ Black.css
stdout_logfile=/var/log/shellinaboxd.log
autostart=false
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
END

tee rserver.conf << END
[program:3_rserver]
command=/usr/lib/rstudio-server/bin/rserver --server-daemonize 0
stdout_logfile=/var/log/rserver.log
autostart=false
autorestart=true
user=root
stopsignal=TERM
numprocs=1
redirect_stderr=true
END

tee jupyter_notebook.conf << END
[program:4_jupyter_notebook]
command=/sbin/runuser -u $nuser -- jupyter notebook -y --no-browser --ip=0.0.0.0 --certfile=/etc/supervisor/conf.d/self.pem --keyfile=/etc/supervisor/conf.d/self.key --config=/home/$nuser/.jupyter/jupyter_notebook_config.py
stdout_logfile=/var/log/jupyter_notebook.log
directory=/home/$nuser
autostart=false
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
autostart=true
autorestart=true
user=root
stopsignal=KILL
numprocs=1
redirect_stderr=true
END

tee update.conf << END
[program:6_update]
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
[program:7_restart_server]
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
echo "Docker ready. User: $nuser Password: $pass Address: $URLsupervisor" | tee ~/docker.txt

docker top $nuser 
exit # exit from su
cd ~
