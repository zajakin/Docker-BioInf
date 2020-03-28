FROM debian:testing
RUN env DEBIAN_FRONTEND=noninteractive apt-get update && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils && \
	env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends && \
	env DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		locales sudo mc wget procps psmisc htop nginx-light libnginx-mod-http-auth-pam \
		shellinabox ssh mosh tmux supervisor bash-completion \
		policykit-1-gnome dbus-x11 firefox-esr geany \
		lxde-core lxlauncher lxterminal lxmenu-data lxtask \
		tigervnc-standalone-server tigervnc-common tigervnc-xorg-extension novnc xbase-clients \
		gdebi-core r-base-core git jupyter-notebook python3-pip \
		bowtie bowtie2 cutadapt samtools fastqc ncbi-blast+ kraken2 python3-htseq rna-star \
		fastp cnvkit seqtk picard-tools bbmap trimmomatic radiant && \
	apt-get autoremove -y && \
	apt-get autoclean -y
# GTK 2 and 3 settings for icons and style, wallpaper   # tophat cufflinks trnascan-se fastx-toolkit 
RUN echo 'gtk-theme-name="Raleigh"\ngtk-icon-theme-name="nuoveXT2"\n' > /etc/skel/.gtkrc-2.0 && \
	mkdir -p /etc/skel/.config/gtk-3.0 && \
	echo '[Settings]\ngtk-theme-name="Raleigh"\ngtk-icon-theme-name="nuoveXT2"\n' > /etc/skel/.config/gtk-3.0/settings.ini && \
	mkdir -p /etc/skel/.config/pcmanfm/LXDE && \
	echo '[*]\nwallpaper_mode=stretch\nwallpaper_common=1\nwallpaper=/usr/share/lxde/wallpapers/lxde_blue.jpg\n' > /etc/skel/.config/pcmanfm/LXDE/desktop-items-0.conf && \
	mkdir -p /etc/skel/.config/libfm && \
	echo '[config]\nquick_exec=1\nterminal=lxterminal\n' > /etc/skel/.config/libfm/libfm.conf && \
	mkdir -p /etc/skel/.config/openbox/ && \
	echo '<?xml version="1.0" encoding="UTF-8"?>\n<theme>\n  <name>Clearlooks</name>\n</theme>\n' > /etc/skel/.config/openbox/lxde-rc.xml && \
	mkdir -p /etc/skel/.config/ && \
	echo '[Added Associations]\ntext/plain=mousepad.desktop;\n' > /etc/skel/.config/mimeapps.list
ENV NOTVISIBLE "in users profile"
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# lv_LV.UTF-8 UTF-8/lv_LV.utf8 UTF-8/' /etc/locale.gen && \
	locale-gen && \
	mkdir -p /run/sshd /var/log/supervisor && \
	echo "export VISIBLE=now" >> /etc/profile
RUN wget -nv https://www.rstudio.org/download/latest/stable/server/bionic/rstudio-server-latest-amd64.deb && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ./rstudio-server-latest-amd64.deb && \
	apt-get autoremove -y && \
	apt-get autoclean -y && \
	rm rstudio-server-latest-amd64.deb
CMD ["/usr/bin/supervisord"]
