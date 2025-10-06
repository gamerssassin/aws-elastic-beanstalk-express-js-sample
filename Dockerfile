# Small base, Node 16 as required
FROM node:16-alpine

# App directory
WORKDIR /app

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
