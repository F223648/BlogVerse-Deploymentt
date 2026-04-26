@Library('jenkins-shared-library@main') _
pipeline {
    agent { label 'linux-agent' }

    environment {
        SLACK_WEBHOOK = credentials('slack-webhook')
    }

    stages {
        stage('Checkout') {
            steps {
                script { env.FAILED_STAGE = 'Checkout' }
                checkout scm
            }
        }

        stage('Build') {
            steps {
                script { env.FAILED_STAGE = 'Build' }
                dir('app') {
                    sh 'npm install'
                }
            }
        }

        stage('Static Analysis') {
            steps {
                script { env.FAILED_STAGE = 'Static Analysis' }
                dir('app') {
                    sh 'npm run test:coverage'
                    // runSonarScan(projectKey: 'sample-app')
                }
                // timeout(time: 5, unit: 'MINUTES') {
                //     waitForQualityGate abortPipeline: true
                // }
            }
        }

        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        script { env.FAILED_STAGE = 'Unit Tests' }
                        dir('app') {
                            sh 'JEST_JUNIT_OUTPUT_NAME=unit.xml npm run test:unit'
                        }
                    }
                    post {
                        always {
                            junit 'app/test-results/unit.xml'
                        }
                    }
                }
                stage('Integration Tests') {
                    steps {
                        script { env.FAILED_STAGE = 'Integration Tests' }
                        dir('app') {
                            sh 'JEST_JUNIT_OUTPUT_NAME=integration.xml npm run test:integration'
                        }
                    }
                    post {
                        always {
                            junit 'app/test-results/integration.xml'
                        }
                    }
                }
            }
        }

        stage('Package') {
            steps {
                script { env.FAILED_STAGE = 'Package' }
                dir('app') {
                    sh 'tar -czvf app.tar.gz index.js package.json node_modules'
                }
            }
        }

        stage('Deploy') {
            steps {
                script { env.FAILED_STAGE = 'Deploy' }
                echo "Deploying to Staging environment..."
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'app/app.tar.gz', allowEmptyArchive: true
        }
        success {
            script {
                def msg = "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
                notifySlack(message: msg, color: 'good')
            }
        }
        failure {
            script {
                def msg = "FAILURE: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'. Stage '${env.FAILED_STAGE}' failed."
                notifySlack(message: msg, color: 'danger')
            }
        }
    }
}
