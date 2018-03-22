FROM python:3.6.4-jessie
MAINTAINER Babim <babim@matmagoc.com>

ENV DEBIAN_FRONTEND noninteractive

# Version of Nginx to install
ENV NGINX_VERSION 1.9.7-1~jessie

RUN apt-key adv \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

RUN echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list

RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        locales \
        gettext \
        ca-certificates \
        nginx \
	git wget

RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales

# Define build arguments: Taiga version
ARG VERSION=3.1.0

# Download taiga.io backend and frontend
RUN mkdir -p /taiga.io/
WORKDIR /taiga.io
RUN wget https://github.com/taigaio/taiga-back/archive/$VERSION.tar.gz
RUN tar xzf $VERSION.tar.gz
RUN mv taiga-back-$VERSION taiga-back
#RUN ln -sf taiga-back-$VERSION taiga-back
RUN rm -f $VERSION.tar.gz
RUN wget https://github.com/taigaio/taiga-front-dist/archive/$VERSION-stable.tar.gz
RUN tar xzf $VERSION-stable.tar.gz
RUN mv taiga-front-dist-$VERSION-stable taiga-front
#RUN ln -sf taiga-front-dist-$VERSION-stable taiga-front
RUN rm -f $VERSION-stable.tar.gz

# specify LANG to ensure python installs locals properly
# fixes benhutchins/docker-taiga-example#4
# ref benhutchins/docker-taiga#15
ENV LANG C

# Install all required dependencies of the backend (we will check on container startup whether we need
# to setup the database first)
WORKDIR /taiga.io/taiga-back
ENV LIBRARY_PATH=/lib:/usr/lib
RUN pip install --no-cache-dir -r requirements.txt

RUN echo "LANG=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_TYPE=en_US.UTF-8" > /etc/default/locale
RUN echo "LC_MESSAGES=POSIX" >> /etc/default/locale
RUN echo "LANGUAGE=en" >> /etc/default/locale

ENV LANG en_US.UTF-8
ENV LC_TYPE en_US.UTF-8
ENV LC_MESSAGES POSIX
ENV LANGUAGE en

# Setup default environment
ENV TAIGA_SSL "false"
ENV TAIGA_HOSTNAME "localhost"
ENV TAIGA_SECRET_KEY `< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-64};echo;`
ENV TAIGA_DB_HOST "localhost"
ENV TAIGA_DB_NAME "postgres"
ENV TAIGA_DB_USER "postgres"
ENV TAIGA_DB_PASSWORD "!!!PLEASE-REPLACE-ME!!!"
ENV TAIGA_PUBLIC_REGISTER_ENABLED "false"
ENV TAIGA_BACKEND_DEBUG "false"
ENV TAIGA_FRONTEND_DEBUG "false"
ENV TAIGA_FEEDBACK_ENABLED "false"
ENV TAIGA_DEFAULT_LANGUAGE "en"
ENV TAIGA_DEFAULT_THEME "material-design"

# Email SMTP
ENV EMAIL_ENABLE "false"
ENV EMAIL_BACKEND 'django.core.mail.backends.smtp.EmailBackend'
ENV EMAIL_USE_TLS "True"
ENV EMAIL_HOST 'smtp.gmail.com'
ENV EMAIL_PORT 587
#ENV EMAIL_HOST_USER 'yourusername@gmail.com'
#ENV EMAIL_HOST_PASSWORD 'yourpassword'
#EMAIL_USE_SSL = True

# LDAP configuration
RUN pip install taiga-contrib-ldap-auth
ENV LDAP_ENABLE "false"
ENV LDAP_SERVER ""
ENV LDAP_PORT 389
ENV LDAP_BIND_DN ""
ENV LDAP_BIND_PASSWORD ""
ENV LDAP_SEARCH_BASE ""
ENV LDAP_SEARCH_PROPERTY "sAMAccountName"
ENV LDAP_EMAIL_PROPERTY 'mail'
ENV LDAP_FULL_NAME_PROPERTY 'displayName'

# Active Directory configuration
RUN apt-get install -y libkrb5-dev libldap2-dev
RUN cd /taiga.io && git clone https://github.com/stemid/taiga-contrib-ad-auth && \
    python /taiga.io/taiga-contrib-ad-auth/setup.py install
ENV AD_ENABLE "false"
ENV AD_REALM "MYDOMAIN.LOCAL"
ENV AD_ALLOWED_DOMAINS "ad.mydomain.local"
ENV AD_LDAP_SERVER "ldaps://ad.mydomain.local/"
ENV AD_LDAP_PORT 636
#ENV AD_SEARCH_BASE "ou=Company,dc=ad,dc=lan"
ENV AD_SEARCH_BASE ""
ENV AD_EMAIL_PROPERTY "mail"
ENV AD_SEARCH_FILTER ""
ENV AD_BIND_DN ""
ENV AD_BIND_PASSWORD ""

# Kerberos configuration
RUN apt-get install -y libkrb5-dev
RUN pip install taiga-contrib-kerberos-auth
ENV KRB5_ENABLE "false"
ENV KRB5_REALM "MYDOMAIN.LOCAL"
ENV KRB5_DOMAINS "mydomain.local"
ENV KRB5_DEFAULT_DOMAIN ""

RUN python manage.py collectstatic --noinput
RUN mkdir /taiga.io/presets
COPY local.py /taiga.io/presets/local.py

# Setup Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Remove all packages that are not required anymore
RUN apt-get purge -y wget git

# Copy files for startup
COPY checkdb.py /taiga.io/checkdb.py
COPY krb5.conf /taiga.io/krb5.conf
COPY entrypoint.sh /entrypoint.sh

# Create a data-directory into which the configuration files will be moved
RUN mkdir /taiga.io/data

RUN apt-get clean && \
    apt-get autoclean && \
    apt-get autoremove -y && \
    rm -rf /build && \
    rm -rf /tmp/* /var/tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup

## Prepare start ##
RUN ln -sf /taiga.io/krb5.conf /etc/krb5.conf && \
	mv /taiga.io /taiga-start && mkdir -p /taiga.io

# Startup
VOLUME /taiga.io

# Expose ports.
EXPOSE 80 443 8000

#WORKDIR /taiga.io/taiga-back
ENTRYPOINT ["/entrypoint.sh"]
#CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
