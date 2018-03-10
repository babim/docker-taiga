FROM babim/alpinebase

# Define build arguments: Taiga version
ARG VERSION=3.1.0

# Install necessary packages
RUN apk add --no-cache nginx ca-certificates wget

# Download taiga.io backend and frontend
RUN mkdir -p /taiga.io/
WORKDIR /taiga.io
RUN wget https://github.com/taigaio/taiga-front-dist/archive/$VERSION-stable.tar.gz
RUN tar xzf $VERSION-stable.tar.gz
RUN ln -sf taiga-front-dist-$VERSION-stable taiga-front
RUN rm -f $VERSION-stable.tar.gz

# Setup Nginx
COPY nginx.conf /etc/nginx/nginx.conf

VOLUME /taiga.io/taiga-front
# Define default command.
CMD ["nginx", "-g", "daemon off;"]
