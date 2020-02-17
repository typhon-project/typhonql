node {
    try{
    notifyBuild()
	properties([
        parameters(
            [string(defaultValue: '/var/site/typhon-ql', name: 'UPDATE_SITE_PATH')]
        )
    ])  
    
    stage('Clone') {
        checkout scm
    }

    stage('Build bundle') {
	    configFileProvider(
        	[configFile(fileId: 'c262b5dc-6fc6-40eb-a271-885950d8cf70', variable: 'MAVEN_SETTINGS')]) {
            sh 'cd typhonql-bundler && mvn -U -B -gs $MAVEN_SETTINGS clean install'
	    }
    }

    stage('Build typhonql') {
	    configFileProvider(
        	[configFile(fileId: 'c262b5dc-6fc6-40eb-a271-885950d8cf70', variable: 'MAVEN_SETTINGS')]) {
        	sh 'mvn -U -B -gs $MAVEN_SETTINGS clean install'
        	sh 'cd typhonql-server && mvn -U -B -gs $MAVEN_SETTINGS clean compile'
        }
    }

    stage('Deploying') {
        if (env.BRANCH_NAME == "master") {
            configFileProvider(
                [configFile(fileId: 'c262b5dc-6fc6-40eb-a271-885950d8cf70', variable: 'MAVEN_SETTINGS')]) {
                sh 'cd typhonql-bundler && mvn -U -B -gs $MAVEN_SETTINGS deploy'
                sh 'mvn -U -B -gs $MAVEN_SETTINGS -pl \'!typhonql-update-site\' deploy'
                sh 'cd typhonql-server && mvn -U -B -gs $MAVEN_SETTINGS clean compile jib:dockerBuild'
            }
        }
    }

    stage('Deploy update site') {
        if (env.BRANCH_NAME == "master") {
            sh 'cd typhonql-update-site && mvn clean package'
            sh "rm -rf ${UPDATE_SITE_PATH}"
            sh "mkdir ${UPDATE_SITE_PATH}"
            sh "cp -a typhonql-update-site/target/. ${UPDATE_SITE_PATH}/"
        }
    }

    }catch (e){
        currentBuild.result = "FAILED"
        throw e
    } finally {
        notifyBuild(currentBuild.result)
    }
}

def notifyBuild(String buildStatus ='STARTED'){
    buildStatus = buildStatus ?: 'SUCCESS'

    def color

    if (buildStatus == 'STARTED') {
        color = '#D4DADF'
    } else if (buildStatus == 'SUCCESS') {
        color = '#BDFFC3'
    } else if (buildStatus == 'UNSTABLE') {
        color = '#FFFE89'
    } else {
        color = '#FF9FA1'
    }

    def msg = "${buildStatus}: `${env.JOB_NAME}` #${env.BUILD_NUMBER}:\n${env.BUILD_URL}"

    slackSend(color: color, message: msg)
}
