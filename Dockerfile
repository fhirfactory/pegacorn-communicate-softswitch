FROM debian:buster
# Reference for this build:
# https://github.com/igorolhovskiy/fusionpbx-docker/blob/4.4/Dockerfile
# https://github.com/PBXForums/fusionpbx-docker/blob/master/Dockerfile

# Expose ports
# https://freeswitch.org/confluence/display/FREESWITCH/Firewall
EXPOSE 80
EXPOSE 443
EXPOSE 5432
EXPOSE 5060/tcp 5060/udp 5070/tcp 5070/udp 5080/tcp 5080/udp
EXPOSE 5066/tcp 7443/tcp
EXPOSE 8021/tcp
EXPOSE 8081-8082/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp
EXPOSE 2855-2856/tcp

# Install Required Dependencies	
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y --allow-unauthenticated \ 		
	apt-transport-https \
	bsdmainutils \
	ca-certificates \
	curl \
	ghostscript \		
	git \
	gnupg2 \
	libtiff5-dev \
	libtiff-tools \
	lsb-release \
	mariadb-client \
	netcat \
	net-tools \
	nginx \
	openssh-server \
	ssl-cert \
	sudo \
	supervisor \
	wget

# Begin freeswitch software install
# https://freeswitch.org/confluence/display/FREESWITCH/Debian+10+Buster
RUN wget -O - https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | apt-key add - \
	&& echo "deb http://files.freeswitch.org/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list \
	&& echo "deb-src http://files.freeswitch.org/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list \
	&& apt-get update \
	&& apt-get install -y \
	memcached \
	freeswitch-meta-bare \
	freeswitch-conf-vanilla \
	freeswitch-mod-commands \
	freeswitch-mod-console \
	freeswitch-mod-logfile \
	freeswitch-lang-en \
	freeswitch-mod-say-en \
	freeswitch-sounds-en-us-callie \
	freeswitch-mod-enum \
	freeswitch-mod-cdr-csv \
	freeswitch-mod-event-socket \
	freeswitch-mod-sofia \
	freeswitch-mod-loopback \
	freeswitch-mod-conference \
	freeswitch-mod-db \
	freeswitch-mod-dptools \
	freeswitch-mod-expr \
	freeswitch-mod-fifo \
	freeswitch-mod-httapi \
	freeswitch-mod-hash \
	freeswitch-mod-esl \
	freeswitch-mod-esf \
	freeswitch-mod-fsv \
	freeswitch-mod-valet-parking \
	freeswitch-mod-dialplan-xml \
	freeswitch-mod-sndfile \
	freeswitch-mod-native-file \
	freeswitch-mod-local-stream \
	freeswitch-mod-tone-stream \
	freeswitch-mod-lua \
	freeswitch-meta-mod-say \
	freeswitch-mod-xml-cdr \
	freeswitch-mod-verto \
	freeswitch-mod-callcenter \
	freeswitch-mod-rtc \
	freeswitch-mod-png \
	freeswitch-mod-json-cdr \
	freeswitch-mod-shout \
	freeswitch-mod-sms \
	freeswitch-mod-sms-dbg \
	freeswitch-mod-cidlookup \
	freeswitch-mod-memcache \
	freeswitch-mod-imagick \
	freeswitch-mod-tts-commandline \
	freeswitch-mod-directory \
	freeswitch-mod-flite \
	freeswitch-mod-distributor \
	freeswitch-meta-codecs \
	freeswitch-music-default \
    && usermod -a -G freeswitch www-data \
    && usermod -a -G www-data freeswitch \
    && chown -R freeswitch:freeswitch /var/lib/freeswitch \
    && chmod -R ug+rw /var/lib/freeswitch \
    && find /var/lib/freeswitch -type d -exec chmod 2770 {} \; \
    && mkdir /usr/share/freeswitch/scripts \
    && chown -R freeswitch:freeswitch /usr/share/freeswitch \
    && chmod -R ug+rw /usr/share/freeswitch \
    && find /usr/share/freeswitch -type d -exec chmod 2770 {} \; \
    && chown -R freeswitch:freeswitch /etc/freeswitch \
    && chmod -R ug+rw /etc/freeswitch \
    && mkdir -p /etc/fusionpbx \
    && chmod 777 /etc/fusionpbx \
    && find /etc/freeswitch -type d -exec chmod 2770 {} \; \
    && chown -R freeswitch:freeswitch /var/log/freeswitch \
    && chmod -R ug+rw /var/log/freeswitch \
    && find /var/log/freeswitch -type d -exec chmod 2770 {} \; \
    && find /etc/freeswitch/autoload_configs/event_socket.conf.xml -type f -exec sed -i 's/::/127.0.0.1/g' {} \; \
    && mkdir -p /run/php/ \
    && apt-get clean

# Configure TLS for FreeSwitch -- create folder to mount pem file
RUN mkdir -p /etc/freeswitch/tls

# Configure SIP
COPY internal.xml /etc/freeswitch/sip_profiles/internal.xml
COPY verto.conf.xml /etc/freeswitch/autoload_configs/verto.conf.xml

# Test WebRTC - https://freeswitch.org/confluence/display/FREESWITCH/mod_verto
COPY directoryusers /etc/freeswitch/directory/default/
COPY conference.conf.xml /etc/freeswitch/autoload_configs/conference.conf.xml
COPY default.xml /etc/freeswitch/directory/default.xml

# Configure https for Nginx web server
RUN touch /etc/nginx/sites-available/pegacorn-communicate.australiaeast.cloudapp.azure.com
COPY default.conf /
RUN cat default.conf > /etc/nginx/sites-available/pegacorn-communicate.australiaeast.cloudapp.azure.com \
	&& ln -s /etc/nginx/sites-available/pegacorn-communicate.australiaeast.cloudapp.azure.com /etc/nginx/sites-enabled/pegacorn-communicate.australiaeast.cloudapp.azure.com \
	&& ln -s /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/private/pegacorn-communicate-freeswitch.site-a.key \
	&& ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/certs/pegacorn-communicate-freeswitch.site-a.crt \
	&& rm /etc/nginx/sites-enabled/default \
	&& rm default.conf
        
# Date-time build argument
ARG IMAGE_BUILD_TIMESTAMP
ENV IMAGE_BUILD_TIMESTAMP=${IMAGE_BUILD_TIMESTAMP}
RUN echo IMAGE_BUILD_TIMESTAMP=${IMAGE_BUILD_TIMESTAMP}

USER root
COPY modules.conf.xml /etc/freeswitch/autoload_configs/modules.conf.xml
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-freeswitch.sh /usr/bin/start-freeswitch.sh

VOLUME ["/etc/freeswitch", "/var/lib/freeswitch", "/usr/share/freeswitch"]

CMD /usr/bin/supervisord -n
