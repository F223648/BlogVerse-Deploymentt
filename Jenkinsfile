@Library('jenkins-shared-library@main') _
pipeline {
    agent { label 'linux-agent' }

    environment {
        SLACK_WEBHOOK = credentials('slack-webhook')
        // In Task 5 and Task 7, we'll need ECR and other variables.
        // ECR_CREDENTIALS = credentials('docker-credentials')
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
                    runSonarScan(projectKey: 'sample-app')
                }
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
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
                // Placeholder for Task 2
            }
        }

        stage('Container Build') {
            steps {
                script { env.FAILED_STAGE = 'Container Build' }
                dir('app') {
                    script {
                        env.GIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                        env.BRANCH_NAME = env.BRANCH_NAME ?: 'main'
                        env.AWS_ACCOUNT = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                        env.IMAGE_NAME = "${env.AWS_ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com/assignment4-app"
                        sh "docker build -t ${env.IMAGE_NAME}:${env.GIT_SHA} -t ${env.IMAGE_NAME}:${env.BRANCH_NAME} ."
                    }
                }
            }
        }

        stage('Security Scan') {
            steps {
                script { env.FAILED_STAGE = 'Security Scan' }
                dir('app') {
                    sh "trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --format table --output trivy-report.txt ${env.IMAGE_NAME}:${env.GIT_SHA}"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'app/trivy-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Push') {
            steps {
                script { env.FAILED_STAGE = 'Push' }
                script {
                    sh "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${env.AWS_ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com"
                    sh "docker push ${env.IMAGE_NAME}:${env.GIT_SHA}"
                    sh "docker push ${env.IMAGE_NAME}:${env.BRANCH_NAME}"
                }
            }
        }

        stage('Deploy-Production') {
            when {
                branch 'main'
            }
            steps {
                script { env.FAILED_STAGE = 'Deploy-Production' }
                script {
                    def ALB_ARN = sh(script: "aws elbv2 describe-load-balancers --names assignment3-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text", returnStdout: true).trim()
                    def LISTENER_80_ARN = sh(script: "aws elbv2 describe-listeners --load-balancer-arn ${ALB_ARN} --query 'Listeners[?Port==\\`80\\`].ListenerArn' --output text", returnStdout: true).trim()
                    def LISTENER_8080_ARN = sh(script: "aws elbv2 describe-listeners --load-balancer-arn ${ALB_ARN} --query 'Listeners[?Port==\\`8080\\`].ListenerArn' --output text", returnStdout: true).trim()
                    
                    def currentTgArn = sh(script: "aws elbv2 describe-listeners --listener-arns ${LISTENER_80_ARN} --query 'Listeners[0].DefaultActions[0].TargetGroupArn' --output text", returnStdout: true).trim()
                    def liveColor = currentTgArn.contains("tg-blue") ? "blue" : "green"
                    def idleColor = liveColor == "blue" ? "green" : "blue"
                    
                    echo "Live color: ${liveColor}. Deploying to Idle color: ${idleColor}."
                    
                    def userDataStr = "#!/bin/bash\\nyum update -y\\nyum install -y docker\\nsystemctl start docker\\nsystemctl enable docker\\naws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${env.AWS_ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com\\ndocker run -d -p 80:3000 ${env.IMAGE_NAME}:${env.GIT_SHA}"
                    def b64UserData = sh(script: "echo -e '${userDataStr}' | base64 -w 0", returnStdout: true).trim()
                    def ltData = "{\\\"UserData\\\":\\\"${b64UserData}\\\"}"
                    
                    def newLtVersion = sh(script: "aws ec2 create-launch-template-version --launch-template-name assignment3-lt --source-version \\$Latest --launch-template-data '${ltData}' --query 'LaunchTemplateVersion.VersionNumber' --output text", returnStdout: true).trim()
                    
                    sh "aws autoscaling update-auto-scaling-group --auto-scaling-group-name assignment3-asg-${idleColor} --launch-template LaunchTemplateName=assignment3-lt,Version=${newLtVersion}"
                    sh "aws autoscaling start-instance-refresh --auto-scaling-group-name assignment3-asg-${idleColor}"
                    
                    echo "Waiting 3 minutes for instances to refresh and become healthy..."
                    sleep time: 180, unit: 'SECONDS'
                    
                    def albDns = sh(script: "aws elbv2 describe-load-balancers --names assignment3-alb --query 'LoadBalancers[0].DNSName' --output text", returnStdout: true).trim()
                    
                    def smokeTestStatus = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://${albDns}:8080/health", returnStdout: true).trim()
                    if (smokeTestStatus != "200") {
                        sh "echo '{\\\"timestamp\\\":\\\"`date -u`\\\", \\\"sha\\\":\\\"${env.GIT_SHA}\\\", \\\"image\\\":\\\"${env.IMAGE_NAME}:${env.GIT_SHA}\\\", \\\"previous\\\":\\\"${liveColor}\\\", \\\"new\\\":\\\"${idleColor}\\\", \\\"result\\\":\\\"failed\\\"}' >> deploy_log.json"
                        sh "aws s3 cp deploy_log.json s3://assignment3-tfstate-your-roll-number/deploy_log.json || true"
                        error "Smoke test failed with HTTP ${smokeTestStatus}. Aborting swap."
                    }
                    
                    def idleTgArn = sh(script: "aws elbv2 describe-target-groups --names assignment3-tg-${idleColor} --query 'TargetGroups[0].TargetGroupArn' --output text", returnStdout: true).trim()
                    sh "aws elbv2 modify-listener --listener-arn ${LISTENER_80_ARN} --default-actions Type=forward,TargetGroupArn=${idleTgArn}"
                    sh "aws elbv2 modify-listener --listener-arn ${LISTENER_8080_ARN} --default-actions Type=forward,TargetGroupArn=${currentTgArn}"
                    
                    sh "echo '{\\\"timestamp\\\":\\\"`date -u`\\\", \\\"sha\\\":\\\"${env.GIT_SHA}\\\", \\\"image\\\":\\\"${env.IMAGE_NAME}:${env.GIT_SHA}\\\", \\\"previous\\\":\\\"${liveColor}\\\", \\\"new\\\":\\\"${idleColor}\\\", \\\"result\\\":\\\"success\\\"}' >> deploy_log.json"
                    sh "aws s3 cp deploy_log.json s3://assignment3-tfstate-your-roll-number/deploy_log.json || true"
                }
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
