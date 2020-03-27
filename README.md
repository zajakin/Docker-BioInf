# Docker-BioInf

### System for generation of multiple Docker containers for students/users/data scientists.

Include Debian/LXDE with noVNC access, RStudio, Jupyter notebook, ShellInABox, SSH, MOSH, Glances.

Containers generated from user tables "staff.tsv" and "users.tsv" (can be generated automatically) on the same IP with 10 ports step.


In each container opened ports/programms:

 * Dashboard (Supervisord) - https://host.domain:port0
 * RStudio - https://host.domain:port0/r
 * Jupier notebook - https://host.domain:port0/j
 * ShellInABox - https://host.domain:port0/b
 * VNC - https://host.domain:port0/n
 * ssh://username@host.domain:port2

                ssh -X username@host.domain -p port2

                mosh username@host.domain -p port1

All services should be started in Dashboard or selected for autostart in "Settings.ini".

Edit "Settings.ini" (generated automaticaly at first run) for your preferences.


 Tasks/containers monitoring programm Glances - http://host.domain:61208
 
 Dr. Pawel Zayakin

 Screenshot:

 ![](https://github.com/zajakin/Docker-BioInf/raw/master/images/preview.png "Screenshot")
 
 