node {
    stage('Clone') {
        checkout scm
    }

    stage('Build bundle') {
        sh 'cd typhonql-bundler && mvn clean install'
    }

    stage('Build typhonql') {
        sh 'cd .. && mvn clean package'
    }
}
