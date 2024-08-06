#!/bin/bash

# Update package manager
echo "Updating package manager..."
sudo yum update -y

# Install git
echo "Installing git..."
sudo yum install git -y

# Install Maven
echo "Installing Maven..."
sudo yum install maven -y

# Check if Java is installed
echo "Checking if Java is installed..."
if ! java -version &> /dev/null; then
    echo "Java is not installed. Installing Java..."
    sudo yum install -y java-1.8.0-openjdk
else
    echo "Java is installed"
fi

# Verify Java installation
java -version

# Define Tomcat version and URL
TOMCAT_VERSION=9.0.93
TOMCAT_URL=https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.93/bin/apache-tomcat-9.0.93.tar.gz

# Download Tomcat
echo "Downloading Tomcat..."
wget $TOMCAT_URL

# Extract Tomcat
echo "Extracting Tomcat..."
tar -xvzf apache-tomcat-${TOMCAT_VERSION}.tar.gz

# Remove the tar.gz file
echo "Removing tar.gz file..."
rm -rf apache-tomcat-${TOMCAT_VERSION}.tar.gz

# Rename the Tomcat directory
echo "Renaming Tomcat directory..."
mv apache-tomcat-${TOMCAT_VERSION} /home/ec2-user/tomcat

# Define variables
TOMCAT_HOME="/home/ec2-user/tomcat"
MANAGER_CONTEXT="$TOMCAT_HOME/webapps/manager/META-INF/context.xml"
HOST_MANAGER_CONTEXT="$TOMCAT_HOME/webapps/host-manager/META-INF/context.xml"
TOMCAT_USERS="$TOMCAT_HOME/conf/tomcat-users.xml"

# Function to modify context.xml files
modify_context_xml() {
  local context_file=$1

  if grep -q 'Valve className="org.apache.catalina.valves.RemoteAddrValve"' "$context_file"; then
    echo "Updating $context_file..."
    sudo sed -i 's|<Valve className="org.apache.catalina.valves.RemoteAddrValve".*|<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve\" allow=\"127\\.\\d+\\.\\d+\\.\\d+|::1\" /> -->|' "$context_file"
  else
    echo "No matching Valve class found in $context_file. No changes made."
  fi
}

# Function to modify tomcat-users.xml file
modify_tomcat_users() {
  local users_xml=$1
  local roles_and_user='
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <user username="tomcat" password="tomcat123" roles="manager-gui,manager-script,manager-jmx,manager-status"/>'

  if grep -q '<user username="tomcat"' "$users_xml"; then
    echo "User tomcat already exists in $users_xml."
  else
    echo "Adding roles and user to $users_xml..."
    sudo sed -i "/<\/tomcat-users>/ i\ $roles_and_user" "$users_xml"
  fi
}

# Modify context.xml files for manager and host-manager
echo "Modifying context.xml files for manager and host-manager..."
modify_context_xml "$MANAGER_CONTEXT"
modify_context_xml "$HOST_MANAGER_CONTEXT"

# Modify tomcat-users.xml file to add roles and user
echo "Modifying tomcat-users.xml file to add roles and user..."
modify_tomcat_users "$TOMCAT_USERS"

# Cloning project from repository
echo "Cloning project from repository..."
git clone https://github.com/varunn777/java-hello-world-with-maven.git

# Changing the directory
cd java-hello-world-with-maven

# Running all the Maven commands, skipping integration testing and deploy
echo "Running Maven commands..."
mvn validate
mvn compile
mvn test
mvn package
mvn install

# Copying the JAR file from the target folder to Tomcat's webapps directory
echo "Copying JAR file to Tomcat's webapps directory..."
cp target/jb-hello-world-maven-0.2.0.jar "$TOMCAT_HOME/webapps/"

# Start Tomcat to apply changes
echo "Starting Tomcat..."
"$TOMCAT_HOME/bin/startup.sh"

echo "Tomcat configuration updated and started successfully."

