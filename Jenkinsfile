node {
	properties([
        parameters(
            [string(defaultValue: '/var/site/typhon-ql', name: 'UPDATE_SITE_PATH')]
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