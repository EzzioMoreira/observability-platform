# Use an official Node.js runtime as a parent image
FROM node:14

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install app dependencies
RUN npm install

# Bundle your app source code into the container
COPY . .

# Expose the port your app will run on
EXPOSE 3000

# Define environment variables if needed (e.g., for configuration)
# ENV VARIABLE_NAME=value

# Start your Node.js application
CMD [ "node", "app.js" ]
