pipeline {
    agent any

    tools {
        maven 'maven' // Ensure the Maven installation name matches the one configured in Jenkins
    }

    environment {
        IMAGE_NAME        = "springbootapp"
        IMAGE_TAG         = "${BUILD_NUMBER}" // Use build number as version
        ACR_NAME          = "jenkinsazure"
        ACR_LOGIN_SERVER  = "${ACR_NAME}.azurecr.io"
        FULL_IMAGE_NAME   = "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
        TENANT_ID         = "ec78375d-0db0-42cf-82a6-2e6403e95936"
        RESOURCE_GROUP    = "Jenkins"
        AKS_CLUSTER       = "springboot"
        K8S_NAMESPACE     = "default"
        K8S_DEPLOYMENT    = "springboot-app"
    }

    stages {
        stage('Checkout From Git') {
            steps {
                git branch: 'prod', url: 'https://github.com/madhuri224/enahanced-petclinc-springboot.git'
            }
        }

        stage('Maven Compile') {
            steps {
                echo "This is Maven Compile Stage"
                sh 'mvn compile'
            }
        }

        stage('Maven Test') {
            steps {
                echo "This is Maven Test Stage"
                sh 'mvn test'
            }
        }

        stage('File System Scan By Trivy') {
    steps {
        echo "Trivy Scan Started"
        sh '''
            # Install Trivy temporarily for this pipeline run
            sudo apt-get update
            sudo apt-get install -y wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install -y trivy

            # Run the Trivy scan
            trivy fs --format table --output trivy-report.txt --severity HIGH,CRITICAL .
        '''
    }
}
       
        stage('Sonar Analysis') {
            environment {
                SCANNER_HOME = tool 'Sonar-scanner'
            }
            steps {
                withSonarQubeEnv('sonarserver') {
    withCredentials([string(credentialsId: 'SONAR_TOKEN', variable: 'SONAR_TOKEN')]) {
        sh '''
            $SCANNER_HOME/bin/sonar-scanner \
            -Dsonar.organization=madhuri224 \
            -Dsonar.projectKey=madhuri224_Springboot \
            -Dsonar.projectName=Springboot \
            -Dsonar.host.url=https://sonarcloud.io \
            -Dsonar.login=$SONAR_TOKEN \
            -Dsonar.java.binaries=target/classes \
            -Dsonar.exclusions=**/trivy-fs-output.txt
        '''
    }
}
        }

        stage('Sonar Quality Gate') {
            steps {
                timeout(time: 1, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonar'
                }
            }
        }
        
        stage('Maven Package') {
            steps {
                echo "Maven Package Started"
                sh 'mvn package'
            }
        }
        
        stage('Docker Build') {
            steps {
                script {
                    echo "Docker Build Started"
                    docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }

        stage('Azure Login to ACR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'azure-acr-sp', usernameVariable: 'AZURE_USERNAME', passwordVariable: 'AZURE_PASSWORD')]) {
                    script {
                        echo "Azure Login Started"
                        sh '''
                            az login --service-principal -u $AZURE_USERNAME -p $AZURE_PASSWORD --tenant $TENANT_ID
                            az acr login --name $ACR_NAME
                        '''
                    }
                }
            }
        }

        stage('Docker Push to ACR') {
            steps {
                script {
                    echo "Docker Push Started"
                    sh '''
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_NAME}
                        docker push ${FULL_IMAGE_NAME}
                    '''
                }
            }
        }

        stage('Azure Login to Kubernetes') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'azure-acr-sp', usernameVariable: 'AZURE_USERNAME', passwordVariable: 'AZURE_PASSWORD')]) {
                    script {
                        echo "Azure Login to Kubernetes Started"
                        sh '''
                            az login --service-principal -u $AZURE_USERNAME -p $AZURE_PASSWORD --tenant $TENANT_ID
                            az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing    
                        '''
                    }
                }
            }
        }

        stage('Kubernetes Deployment') {
            steps {
                script {
                    echo "Kubernetes Deployment Stage Started"

                    def output = sh(
                        script: "kubectl get deployment ${K8S_DEPLOYMENT} -n $K8S_NAMESPACE --ignore-not-found",
                        returnStdout: true
                    ).trim()

                    def deploymentExists = output != ""

                    if (deploymentExists) {
                        echo "Deployment exists. Performing rolling update with new image: ${BUILD_NUMBER}"
                        sh """
                            kubectl set image deployment/${K8S_DEPLOYMENT} \
                            ${K8S_DEPLOYMENT}=${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${BUILD_NUMBER} \
                            -n $K8S_NAMESPACE
                        """
                    } else {
                        echo "Deployment not found. Creating new deployment from template"
                        sh """
                            sed "s/__IMAGE_TAG__/${BUILD_NUMBER}/" k8s/sprinboot-deployment.yaml > k8s/tmp-deployment.yaml
                            kubectl apply -f k8s/tmp-deployment.yaml -n $K8S_NAMESPACE
                        """
                    }
                }
            }
        }
    }   
}
