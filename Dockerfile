# Target for development
FROM node:18-slim As dev
ENV NODE_ENV=development
ENV DOCKERIZE_VERSION v0.6.1
WORKDIR /app
COPY --chown=node:node package.json yarn.lock ./
RUN apt-get -qq update \
  && apt-get -qq install -y wget ca-certificates git procps openssh-client --no-install-recommends \
  && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
  && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
  && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
  && yarn install
USER node

# Target for production build
FROM node:18-slim As build
WORKDIR /app
COPY --chown=node:node package.json ./
COPY --chown=node:node --from=dev /app/node_modules ./node_modules
COPY --chown=node:node . .
RUN yarn build
ENV NODE_ENV production
RUN mv node_modules node_modules_dev \
  && yarn install --production --frozen-lockfile \
  && yarn cache clean --all \
  && yarn autoclean --force
USER node

# Target for production
FROM node:18-slim As prod
ENV NODE_ENV=production
WORKDIR /app
COPY --chown=node:node --from=build /app/node_modules ./node_modules
COPY --chown=node:node --from=build /app/dist ./dist
RUN apt-get -qq update && apt-get install -y \
  vim \
  && rm -rf /var/lib/apt/lists/* \
  && yarn global add pm2 --ignore-engines \
  && pm2 install pm2-logrotate \
  && pm2 set pm2-logrotate:compress true \
  && pm2 set pm2-logrotate:max_size 50M \
  && pm2 set pm2-logrotate:rotateInterval 26 3 * * * \
  && chown -R node:node /app
USER node
EXPOSE 3000
CMD ["pm2-runtime", "dist/main.js", "--instances", "max"]