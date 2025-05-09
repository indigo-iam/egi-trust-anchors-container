pipeline {

  agent { label 'docker' }
  
  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
    timeout(time: 3, unit: 'HOURS')
  }
  
  triggers {
    cron('@daily')
  }
  
  stages {
    stage('build image') {
      steps {
        script {
          def dockerImage = docker.build("indigoiam/egi-trustanchors:${env.BRANCH_NAME}", "--no-cache -f ./Dockerfile .")
          docker.withRegistry('https://index.docker.io/v1/', "docker-cnafsoftwaredevel") {
            dockerImage.push()
          }
        }
      }
    }
  }
  post {
    failure {
      mattermostSend(message: "${env.JOB_NAME} - ${env.BUILD_NUMBER} has failed (<${env.BUILD_URL}|Open>)", color: "danger")
    }
    changed {
      script{
        if ('SUCCESS'.equals(currentBuild.result)) {
          mattermostSend(message: "${env.JOB_NAME} - ${env.BUILD_NUMBER} Back to normal (<${env.BUILD_URL}|Open>)", color: "good")
        }
      }
    }
  }
}


