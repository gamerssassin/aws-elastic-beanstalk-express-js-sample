# Small base, Node 16 as required
FROM node:16-alpine

# App directory
WORKDIR /app

# Update OpenSSL (fixes Issues)
RUN apk update && apk upgrade --no-cache openssl

# Update global npm (fixes semver/ip issues)
RUN npm i -g npm@10.2.0

# Install only prod deps (tests/dev stuff stays out of the final image)
COPY package*.json ./
# Deps
RUN npm install --only=production

# Copy the rest of the app
COPY . .

# The app listens on 8080
EXPOSE 8080

# Start the server
CMD ["node", "app.js"]
