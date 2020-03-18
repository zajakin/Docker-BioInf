# Docker-BioInf

### System for generation of multiple Docker containers for students/users/data scientists.

Include LXDE with noVNC access, RStudio, Jupyter notebook, ShellInABox, SSH, Glances.

Containers generated from user tables "staff.tsv" and "users.tsv" (can be generated automatically) on the same IP with 10 ports step.


In each container opened ports/programms:

 * Dashboard (Supervisord) - https://host.domain:port0
 * ssh -X username@host.domain -p port2
 * RStudio (should be started in Dashboard) - https://host.domain:port0/r
 * Jupier notebook (should be started in Dashboard) - https://host.domain:port0/j
 * ShellInABox (should be started in Dashboard) - https://host.domain:port0/b
 * VNC (should be started in Dashboard) - https://host.domain:port1/vnc.html
 
    Edit Settings.ini (generated automaticaly at first run) for your preferences.


 Tasks/containers monitoring programm Glances - http://host.domain:61208
 
 Dr. Pawel Zayakin

 Screenshot:

 ![](https://github.com/zajakin/Docker-BioInf/raw/master/preview.png "Screenshot")
 
 