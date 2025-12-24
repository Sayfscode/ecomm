pipeline {
  agent any

  environment {
    DEV_REPO = "yourdockerhub/dev"
    PROD_REPO = "yourdockerhub/prod"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout([$class: 'GitSCM',
          branches: [[name: "${env.BRANCH_NAME}"]],
          doGenerateSubmoduleConfigurations: false,
          extensions: [],
          userRemoteConfigs: [[
            url: 'https://github.com/Sayfscode/ecomm.git',
            credentialsId: 'github-token' 
          ]]
        ])
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          if (env.BRANCH_NAME == 'dev') {
            sh 'docker build -t $DEV_REPO:latest .'
          } else if (env.BRANCH_NAME == 'master') {
            sh 'docker build -t $PROD_REPO:latest .'
          }
        }
      }
    }

    stage('Push Docker Image') {
      steps {
        script {
          if (env.BRANCH_NAME == 'dev') {
            sh 'docker push $DEV_REPO:latest'
          } else if (env.BRANCH_NAME == 'master') {
            sh 'docker push $PROD_REPO:latest'
          }
        }
      }
    }

    stage('Deploy') {
      when {
        branch 'master'
      }
      steps {
        sh './deploy.sh'
      }
    }
  }

  triggers {
    githubPush()
  }
}
