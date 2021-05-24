FROM node:latest
LABEL description="lwl 学习笔记"
WORKDIR /docs
RUN npm install -g docsify-cli@latest
EXPOSE 9999/tcp
ENTRYPOINT docsify serve .