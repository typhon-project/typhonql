node {
	properties([
        parameters(
            [string(defaultValue: '/var/site/nemo2', name: 'UPDATE_SITE_PATH')]
        )
    ])  

    stage('Clone') {
        checkout scm
    }

    stage('Build bundle') {
        sh 'cd typhonql-bundler && mvn clean install'
    }

    stage('Build typhonql') {
        sh 'mvn clean package'
    }

    stage('Deploy update site') {
		sh "rm -rf ${UPDATE_SITE_PATH}"
		sh "mkdir ${UPDATE_SITE_PATH}"
        sh "cp -a typhonql-update-site/target/. ${UPDATE_SITE_PATH}/"
    }
}