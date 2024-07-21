# Use the latest Ubuntu image as the base
FROM library/ubuntu:latest

# Update package lists and install cowsay, fortune, and netcat
RUN apt-get update -y && apt-get install -y cowsay fortune netcat

# Ensure the binary paths are included in PATH
ENV PATH="/usr/games:/usr/local/games:${PATH}"

# Check paths
RUN echo $PATH
RUN ls -l /usr/games
RUN ls -l /usr/local/games
RUN which cowsay
RUN which fortune

# Copy the script into the container
COPY wisecow.sh /usr/local/bin/wisecow.sh

# Make the script executable
RUN chmod +x /usr/local/bin/wisecow.sh

# Set the script as the entrypoint
ENTRYPOINT ["/usr/local/bin/wisecow.sh"]

# Expose the port 4499
EXPOSE 4499