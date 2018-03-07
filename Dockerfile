FROM python:3.6.4-alpine
MAINTAINER Babim <babim@matmagoc.com>

# Define build arguments: Taiga version
ARG VERSION=3.1.0

# Install necessary packages
RUN apk update --no-cache &&\
    apk add --no-cache ca-certificates wget git postgresql-dev musl-dev gcc jpeg-dev zlib-dev libxml2-dev libxslt-dev libffi-dev &&\
    update-ca-certificates

# Download taiga.io backend and frontend
RUN mkdir -p /taiga.io/
WORKDIR /taiga.io
RUN wget https://github.com/taigaio/taiga-back/archive/$VERSION.tar.gz
RUN tar xzf $VERSION.tar.gz
RUN ln -sf taiga-back-$VERSION taiga-back
RUN rm -f $VERSION.tar.gz

# Install all required dependencies of the backend (we will check on container startup whether we need
# to setup the database first)
WORKDIR /taiga.io/taiga-back-$VERSION
ENV LIBRARY_PATH=/lib:/usr/lib
RUN pip install --no-cache-dir -r requirements.txt

# Setup default environmento
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

# Active Directory configuration
RUN apk add --no-cache krb5-dev openldap-dev
RUN cd /taiga.io && git clone https://github.com/stemid/taiga-contrib-ad-auth && \
    python /taiga.io/taiga-contrib-ad-auth/setup.py install
ENV AD_ENABLE "false"
ENV AD_REALM "DOMAIN.LAN"
ENV AD_ALLOWED_DOMAINS "ad.domain.lan"
ENV AD_LDAP_SERVER "ldaps://ad.domain.lan/"
ENV AD_LDAP_PORT 636
ENV AD_SEARCH_BASE ""
ENV AD_EMAIL_PROPERTY "mail"
ENV AD_SEARCH_FILTER ""
ENV AD_BIND_DN ""
ENV AD_BIND_PASSWORD ""

# LDAP configuration
RUN pip install taiga-contrib-ldap-auth
ENV LDAP_ENABLE "false"
ENV LDAP_SERVER ""
ENV LDAP_PORT 389
ENV LDAP_BIND_DN ""
ENV LDAP_BIND_PASSWORD ""
ENV LDAP_SEARCH_BASE ""
ENV LDAP_SEARCH_PROPERTY "sAMAccountName"
ENV LDAP_EMAIL_PROPERTY = 'mail'
ENV LDAP_FULL_NAME_PROPERTY = 'displayName'

RUN python manage.py collectstatic --noinput
RUN mkdir /taiga.io/presets
COPY local.py /taiga.io/presets/local.py

# Remove all packages that are not required anymore
RUN apk del gcc wget git musl-dev libxml2-dev
RUN apk add gettext

# Copy files for startup
COPY checkdb.py /taiga.io/checkdb.py
COPY entrypoint.sh /taiga.io/entrypoint.sh

# Create a data-directory into which the configuration files will be moved
RUN mkdir /taiga.io/data

# Startup
WORKDIR /taiga.io/taiga-back
ENTRYPOINT ["/taiga.io/entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
