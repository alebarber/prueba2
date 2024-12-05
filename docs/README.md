# Proyecto de Jenkins y Docker con Terraform

Este repositorio contiene la configuración necesaria para crear un entorno de integración continua utilizando Jenkins, Docker y Terraform. A través de este proyecto, se establece un pipeline de Jenkins que ejecuta pruebas automatizadas, compila un ejecutable y entrega el artefacto final.  

## PreRequisitos 

Antes de empezar, tendremos que tener instalado en nuestro equipo local:  
### 1. **Git**

### 2. **Docker Desktop**

### 3. **Terraform**

### 4. **Jenkins**


## Pasos
## 1. Crear el fork y clonar repositorio.
Lo primero será hacer un fork desde el repositorio del tutorial *https://www.jenkins.io/doc/tutorials/build-a-python-app-with-pyinstaller/*

Para trabajar en el repositorio, lo clonaremos en nuestra máquina local:
   ```bash
   git clone https://github.com/tu_usuario/tu_repositorio
   cd tu_repositorio
   ```

## 2. Ficheros necesarios.

A continuación se detallan los ficheros necesarios para ejecutar este proyecto:

### 2.1 **Dockerfile**

Este archivo crea una imagen Docker personalizada de Jenkins. En la imagen se incluyen las configuraciones necesarias para que Jenkins pueda ejecutar Docker dentro de los contenedores (Docker-in-Docker). Aquí se define la base de Jenkins y otras configuraciones

```Dockerfile
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
```  

### 2.2 **main.tf**
Este archivo configura la infraestructura necesaria utilizando Terraform. Crea una red Docker y dos contenedores, uno para Jenkins y otro para la ejecución de Docker dentro de Jenkins (DinD).

```
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

resource "docker_network" "jenkins_network" {
  name = "jenkins"
}

resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}

resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

resource "docker_container" "docker_in_docker" {
  image      = "docker:dind"
  name       = "jenkins-docker"
  rm         = true
  privileged = true
  
  networks_advanced {
    name     = docker_network.jenkins_network.name
    aliases  = ["docker"]  
  }
  
  env = [
    "DOCKER_TLS_CERTDIR=/certs"
  ]
  
  volumes {
    container_path = "/var/jenkins_home"
    volume_name    = docker_volume.jenkins_data.name
  }
  
  volumes {
    container_path = "/certs/client"
    volume_name    = docker_volume.jenkins_docker_certs.name
  }
  
  ports {
    internal = 2376
    external = 2376
  }
}

resource "docker_container" "jenkins_blueocean" {
  image   = "jenkins-custom"
  name    = "jenkins-blueocean"
  restart = "on-failure"
  
  networks_advanced {
    name     = docker_network.jenkins_network.name
    aliases  = ["docker"]  
  }
  
  env = [
    "DOCKER_HOST=tcp://docker:2376", 
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1"
  ]
  
  ports {
    internal = 8080
    external = 8080
  }
  
  ports {
    internal = 50000
    external = 50000
  }
  
  volumes {
    container_path = "/var/jenkins_home"
    volume_name    = docker_volume.jenkins_data.name
  }
  
  volumes {
    container_path = "/certs/client"
    volume_name    = docker_volume.jenkins_docker_certs.name
    read_only      = true
  }

  depends_on = [docker_container.docker_in_docker]
}
```

### 2.3 **Jenkinsfile**

Este archivo define el pipeline de Jenkins. El pipeline está dividido en tres etapas: Build, Test y Deliver. En cada etapa se usa un contenedor Docker específico para ejecutar las tareas correspondientes.
``` 
pipeline {
  agent any 
  stages {
    stage('Build') { 
      steps {
        sh 'python3 -m py_compile sources/add2vals.py sources/calc.py' 
      }
    }
    stage('Test') {
      steps {
        sh 'py.test --junit-xml test-reports/results.xml sources/test_calc.py'
      }
      post {
        always {
          junit 'test-reports/results.xml'
        }
      }
    }
    stage('Deliver') { 
      steps {
        sh "pyinstaller --onefile sources/add2vals.py" 
      }
      post {
        success {
          archiveArtifacts 'dist/add2vals' 
        }
      }
    }
  }
}  
```

## 3. Ejecución y subida a GitHub.  

Primero, construimos la imagen Docker ejecutando el siguiente comando en el directorio donde se encuentre el Dockerfile:

``` bash
docker build -t jenkins-custom . #Importante que tenga este nombre
docker images #Comprueba si la imagen se creo correctamente
```

Luego en *tu_repositorio/terraform/* debemos tener el archivo *main.fr*, desde este mismo directorio ejecutamos los siguientes comandos:  
``` bash
terraform init
terraform plan # Opcional
terraform apply
docker ps #Comprobamos si los contenedores se crearon correctamente
docker network ls #Comprobamos si la red se creo correctamente
```
Es importante tambien que el fichero Jenkinsfile este en el directorio *tu_repositorio/jenkins/*.  

Por último, subiremos todos los archivos a nuestro repositorio en GitHub ya que luego accederemos desde jenkins directamente al repositorio del fork.
``` bash
git add .
git commit -m "cambios"
git push origin main #main es nuestra rama principal del repositorio
```

## 4. Configuración de Jenkins y ejecución del pipeline.

### 4.1. Acceder a Jenkins  

Una vez que creado y levantado el contenedor de Jenkins, abrimos el navegador y accedemos a: 
http://localhost:8080

Esto abrirá la interfaz de Jenkins en el navegador, la primera vez que accedamos a Jenkins, pedirá un **password de administrador inicial** para desbloquear la instalación. Podemos encontrar este password ejecutando:

  ``` bash
  docker exec -it jenkins-blueocean /bin/bash
  $ cat /var/jenkins_home/secrets/initialAdminPassword
  ```

Copiamos el resultando y seleccionamos el botón *"Unlock"*

### 4.2 Instalar Plugins Recomendados

Después de desbloquear Jenkins, pedirá que seleccionemos qué plugins deseamos instalar. Jenkins ofrece dos opciones:

- **Install suggested plugins (Instalar plugins recomendados)**: Esta opción instala un conjunto de plugins comunes y útiles para la mayoría de los proyectos.
- **Select plugins to install (Seleccionar plugins para instalar)**: Para una instalación más personalizada, se puede seleccionar los plugins que necesitemos.

Para la mayoría de los usuarios, la opción recomendada es elegir **Install suggested plugins**. Jenkins descargará e instalará los plugins necesarios para el correcto funcionamiento del sistema.

## 4.3 Crear usuario

Después de instalar los plugins, pedirá que configuremos un usuario administrador. Se puede omitir este paso y usar el usuario por defecto (que es el administrador), si no:

Ingresamos un **nombre de usuario**, **contraseña** y una **dirección de correo electrónico** para el primer usuario y pinchamos en **Save and Finish** para completar la configuración.


## 4.4 Configurar acceso al repositorio GitHub

En el menú principal de Jenkins, vamos a *Manage Jenkins*, seleccionamos *credentials* -> *System* -> *global credentials* y pinchamos en el botón *+ Add Credentials* donde pondremos Username With Password y al rellenar los datos le daremos a create. 


## 4.5 Configuracion y ejecución del Pipeline

Una vez que Jenkins esté configurado, es hora de configurar el **Pipeline**

- En el menú principal de Jenkins, hacemos clic en *New Item*
- Elegimos *Pipeline* y asignamos un nombre al proyecto, por ejemplo: `prueba2`.
- Una vez creado el pipeline, vamos a la sección *Pipeline* dentro de la configuración.
- En la opción *Definition*, seleccionamos **Pipeline script from SCM** ya que el Jenkinsfile está en nuestro repositorio de GitHub.
- En **SCM**, seleccionamos *Git* y en **Repository URL**, ingresamos la URL del repositorio en GitHub https://github.com/usuario/repositorio
- Añadimos las credenciales de acceso de GitHub añadidas anteriormente.
- En Branch Specifier pondremos */main en nuestro caso que es la rama principal del repositorio.
-Por último, en Script Path pondremos *jenkins/Jenkinsfile* y seleccionamos Apply y luego Guardar.

Una vez configurado todo, le daremos a *Build Now* para ejecutar el pipeline, Jenkins comenzará a ejecutar las etapas del Jenkinsfile (**Build**, **Test**, y **Deliver**) y mostrará los resultados en tiempo real en la interfaz web.

Podremos ver los resultados de cada etapa y mas información directamente desde la interfaz del panel de control, como por ejemplo, en status podremos ver la creación del artefacto python.  



Con estos pasos, habremos configurado Jenkins desde `localhost:8080`.
