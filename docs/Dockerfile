FROM jenkins/jenkins:2.479.2-jdk17
USER root
RUN apt-get update && apt-get install -y lsb-release

# Agregar la clave pública de Docker
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
    https://download.docker.com/linux/debian/gpg

# Agregar Docker
RUN echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv 
RUN pip install --break-system-packages pyinstaller
RUN pip install --break-system-packages pytest

RUN groupadd -f docker
RUN usermod -aG docker jenkins

# Instalar los complementos de Jenkins necesarios
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow token-macro json-path-api"
