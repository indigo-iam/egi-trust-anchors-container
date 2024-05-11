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
          def dockerImage = docker.build("indigoiam/egi-trustanchors:${env.BRANCH_NAME}", "-f ./Dockerfile .")
          docker.withRegistry('https://index.docker.io/v1/', "docker-cnafsoftwaredevel") {
            dockerImage.push()
          }
        }
      }
    }
  }
}


