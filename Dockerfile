# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Expose both ports (optional; containers only care about internal ports)
EXPOSE 3000 4000

# Default CMD (we’ll override in Compose)
CMD ["node", "server.js"]
