pipeline {

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
        PATH="/opt/anaconda/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/MacGPG2/bin"
  }

  agent {
    node {
      label 'ci-community-docker'
    }
  }

  stages {

    stage('Package & Dockerize') {
      steps {
        withMaven( maven: 'apache-maven-3.0.5' ) {
            sh 'mvn -B deploy'
        }
      }
    }
  }
}
