FROM jetty:11-jdk17

# Set environment variable (optional, for clarity)
ENV WAR_FILE petclinic.war

# Copy your WAR file into Jetty’s webapps directory
COPY ./target/petclinic.war /var/lib/jetty/webapps/ROOT.war

# Expose Jetty’s default port
EXPOSE 8080