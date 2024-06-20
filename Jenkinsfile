pipeline {
    agent any

    tools{
        jdk 'jdk17'
        maven 'maven3'
    }

    environment{
        SCANNER_HOME= tool 'sonar-scanner'
        TEMPLATE_PATH="@/home/odennav/trivy/html.tpl"
        DATE=$(date +"%Y-%m-%d_%H-%M")
    }

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/odennav/boardgame-devops-pipeline-project.git'
            }
        }
       
        stage('Clear Workspace') {
            steps {
                sh "cleanWs()"
            }
        }

        stage('Maven Clean Phase') {
            steps {
                sh "mvn clean"
            }
        }

        stage('Maven Compile Phase') {
            steps {
                sh "mvn compile"
            }
        }
 
        stage('Maven Test Phase') {
            steps {
                sh "mvn test"
            }
        }

        stage('Trivy Filesystem  Scan') {
            steps {
                sh """trivy fs --security-checks vuln,secret,misconfig --format template --template ${TEMPLATE_PATH} --output trivy_fs_report_$DATE.html . """
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('sonar'){
                    sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=BoardGame -Dsonar.java.binaries=.  -Dsonar.projectKey=BoardGame '''
                }    
            }
        }
  
        stage('SonarQube Quality Gate') {
            steps {
                script {
                  waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'   
                }     
            }
        }


        stage('Maven Build Phase') {
            steps {
                sh "mvn package"
            }
        }

        stage('Publish Artifacts to Nexus') {
            steps {
              withMaven(globalMavenSettingsConfig: 'global-settings', jdk: 'jdk17', maven: 'maven3', mavenSettingsConfig:",traceability: true) {
                  sh "mvn deploy"
              }  
            }
        }

        stage('Build & Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker build -t odennav/boardgame:v1 ./boardgame"
                    }
                }
                
            }
        }

        stage('Scan Docker Image') {
            steps {
                sh """trivy image --security-checks vuln,secret,misconfig --format template --template ${TEMPLATE_PATH} --output trivy_image_scan_report_$DATE.html . """

            }
        }


        stage('Push Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker push  odennav/boardgame:v1 "
                    }
                }
                
            }
        }


        stage('Deploy to Kubernetes Cluster') {
            steps {
                withKubeConfig(caCertificate:",clusterName: 'kubernetes',contextName:",credentialsId:'k8s-cred',namespace:'boardgame',restrictKubeConfigAccess:false,serverUrl:'https://172.31.8.1.146:6443'){
                    sh "kubectl apply -f kubernetes-manifests/boardgame-manifests" 
                {
                
            }
        }

        stage('Verify Kubernetes Deployments') {
            steps {
                withKubeConfig(caCertificate:",clusterName: 'kubernetes',contextName:",credentialsId:'k8s-cred',namespace:'boardgame',restrictKubeConfigAccess:false,serverUrl:'https://172.31.8.1.146:6443'){
                    sh "kubectl get pods" 
                    sh "kubectl get svc" 
                {
                
            }
        }

    }
    post {
        always {
            archiveArtifacts artifacts: "trivy_report_*.html", fingerprint: true    
            publishHTML (target: [
                allowMissing: false,
                alwaysLinkToLastBuild: false,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'trivy_report_*.html',
                reportName: 'Trivy Scan',
                ])

        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def pipelineStatus = currentBuild.result ?: 'UNKNOWN'
            def bannerColor = pipelineStatus.toUpperCase() == 'SUCCESS' ? 'green' : 'red'

            def body = """
                <html>
                <body>
                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                <h2>${jobName} - Build ${buildNumber}</h2>
                <div style="background-color: ${bannerColor}; padding: 10px;">
                <h3 style="color: white;">Pipeline Status: ${pipelineStatus.toUpperCase()}</h3>
                </div>
                <p>Check the <a href="${BUILD_URL}">console output</a>.</p>
                </div>
                </body>
                </html>
            """

            emailext (
                subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus.toUpperCase()}",
                body: body,
                to: 'odennav@gmail.com',
                from: 'jenkins@example.com',
                replyTo: 'jenkins@example.com',
                mimeType: 'text/html',
                attachmentsPattern: 'trivy_image_scan_report_$DATE.html'
            )
        }                    

        }
    }
}

