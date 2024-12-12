FROM node:18.18.1
WORKDIR /app/server
COPY package*.json ./
RUN npm install
EXPOSE 8857
CMD [ "node","index" ]
