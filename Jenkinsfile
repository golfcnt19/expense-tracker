// Pipeline สำหรับ Jenkins — ทำงานเทียบเท่ากับ .github/workflows/ci.yml
//
// มีไว้เพราะหลายองค์กร (โดยเฉพาะสายธนาคาร) ใช้ Jenkins ที่รันหลังไฟร์วอลล์
// ไม่ได้ใช้ GitHub Actions โครงนี้จึงเตรียมไว้ให้ย้ายไปรันได้ทันที
//
// ต้องมีใน Jenkins: Docker Pipeline plugin และ agent ที่รัน container ได้

pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        disableConcurrentBuilds(abortPrevious: true)
    }

    environment {
        JAVA_VERSION = '25'
        DB_NAME      = 'expense_tracker_test'
        DB_USER      = 'postgres'
        DB_PASSWORD  = credentials('expense-test-db-password')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
            }
        }

        stage('API') {
            agent {
                docker {
                    image "eclipse-temurin:${JAVA_VERSION}-jdk"
                    // แชร์ Maven cache ข้าม build ไม่ต้องโหลด dependency ใหม่ทุกครั้ง
                    args '-v $HOME/.m2:/root/.m2 --network host'
                    reuseNode true
                }
            }
            steps {
                // เทสต์ต้องรันกับ PostgreSQL จริง ชนิดเดียวกับ production
                sh """
                    docker run -d --name pg-\$BUILD_NUMBER \
                        -e POSTGRES_USER=${DB_USER} \
                        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
                        -e POSTGRES_DB=${DB_NAME} \
                        -p 5432:5432 postgres:18

                    for i in \$(seq 1 30); do
                        docker exec pg-\$BUILD_NUMBER pg_isready -U ${DB_USER} && break
                        sleep 2
                    done
                """
                dir('api') {
                    sh '''
                        export DB_URL=jdbc:postgresql://localhost:5432/$DB_NAME
                        export DB_USER=$DB_USER
                        export DB_PASSWORD=$DB_PASSWORD
                        ./mvnw -B verify
                        ./mvnw -B -DskipTests package
                    '''
                }
            }
            post {
                always {
                    sh 'docker rm -f pg-$BUILD_NUMBER || true'
                    junit allowEmptyResults: true, testResults: 'api/target/surefire-reports/*.xml'
                    archiveArtifacts artifacts: 'api/target/*.jar', allowEmptyArchive: true
                }
            }
        }

        stage('Web') {
            agent {
                docker { image 'node:24'; reuseNode true }
            }
            steps {
                dir('web') {
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'web/dist/**', allowEmptyArchive: true
                }
            }
        }

        stage('Mobile') {
            agent {
                docker { image 'ghcr.io/cirruslabs/flutter:stable'; reuseNode true }
            }
            steps {
                dir('mobile') {
                    sh 'flutter pub get'
                    sh 'flutter analyze --fatal-infos'
                    sh 'flutter test'
                    sh 'flutter build web --release'
                }
            }
        }

        stage('Container image') {
            steps {
                sh 'docker build -f Containerfile -t expense-api:$GIT_SHORT .'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            echo "Build ${env.BUILD_NUMBER} ล้มเหลว — ดู log ที่ ${env.BUILD_URL}"
        }
    }
}
