FROM node:carbon

ARG NODEJS_PORT

WORKDIR /usr/src/app

RUN npm install

EXPOSE $NODEJS_PORT

CMD [ "npm", "start" ]
