# Use Bun as the base image
FROM oven/bun:alpine

# Set default environment variables
ARG NODE_ENV=production
ARG DATABASE_URL

# Define working directory in the container
WORKDIR /app

# Add a user and group for running the application
RUN addgroup -g 1001 nodejs && adduser -S nodejs -u 1001

# Copy package.json and bun.lockb files to the working directory
COPY package.json bun.lockb ./

# Install dependencies using Bun
RUN bun install

# Copy all JavaScript files to the working directory
COPY *.js ./

# Set environment variables for Node.js application
ENV NODE_ENV=${NODE_ENV}

# Switch to the non-root user
USER nodejs

# Expose port 3000 for the application
EXPOSE 3000

# Define the command to run the application using Bun
CMD ["bun", "start"]
