FROM  debian:testing
#  docker pull debian:testing && docker run -it --rm --name test debian:testing bash
RUN sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources && \
  env DEBIAN_FRONTEND=noninteractive apt-get update --allow-releaseinfo-change && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils whiptail && \
	env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends && \
	env DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		locales sudo mc curl wget procps psmisc htop nginx-light libnginx-mod-http-auth-pam usrmerge \
		shellinabox ssh mosh tmux supervisor bash-completion gpm bzip2 geany \
		at-spi2-core lxqt-policykit dbus-x11 firefox-esr gpicview zathura meld fonts-firacode \
		build-essential gfortran libgfortran-13-dev liblapack-dev libblas-dev libopenblas-dev \
		libxml2-dev libjpeg-dev libcurl4-openssl-dev libssl-dev zlib1g-dev \
		lxde-core lxlauncher lxterminal lxmenu-data lxtask synaptic xarchiver \
		tigervnc-standalone-server tigervnc-common tigervnc-xorg-extension tigervnc-tools novnc xbase-clients \
		gdebi-core r-base-core git jupyter-notebook python3-pip \
		bowtie bowtie2 cutadapt fastqc samtools ncbi-blast+ kraken2 python3-htseq rna-star \
		fastp cnvkit seqtk cufflinks bbmap trnascan-se trimmomatic radiant picard-tools \
		sortmerna bcftools gnumeric bedtools gffread igv && \
	apt-get autoremove -y && \
	apt-get autoclean -y
# GTK 2 and 3 settings for icons and style, wallpaper   # apt-get install -y --no-install-recommends tophat fastx-toolkit # lxqt-policykit policykit-1-gnome
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
	sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# lv_LV.UTF-8 UTF-8/lv_LV.utf8 UTF-8/' /etc/locale.gen && \
	locale-gen && \
	mkdir -p /run/sshd /var/log/supervisor && \
	echo "export VISIBLE=now" >> /etc/profile
# RUN  wget -nv http://ftp.de.debian.org/debian/pool/main/o/openssl/libssl1.1_1.1.1n-0+deb11u3_amd64.deb && \
# 	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ./libssl1.1_1.1.1n-0+deb11u3_amd64.deb && \
# 	rm libssl1.1_1.1.1n-0+deb11u3_amd64.deb
RUN wget -nv https://www.rstudio.org/download/latest/stable/server/jammy/rstudio-server-latest-amd64.deb && \
  env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ./rstudio-server-latest-amd64.deb && \
	apt-get autoremove -y && \
	apt-get autoclean -y && \
	rm rstudio-server-latest-amd64.deb
#RUN wget -q -O- https://aka.ms/install-vscode-server/setup.sh | sh # vscode requirements gnome-keyring python3-minimal ca-certificates
RUN apt-mark showmanual > /image_packages.txt
CMD ["/usr/bin/supervisord"]
