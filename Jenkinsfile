node('ci-community-docker') {

  stage('Init') {
    checkout([$class: 'GitSCM', branches: [[name: '2b96a9ec0b098020d7cf9f19e09678367ede6fc7' ]],
     userRemoteConfigs: [[url: 'https://github.com/geohazards-tep/dcs-rss-snap-s1-insar.git']]])
  }

  stage('Package & Dockerize') {
    withMaven( maven: 'apache-maven-3.0.5' ) {
            sh 'mvn -B deploy'
        }
  }

}
