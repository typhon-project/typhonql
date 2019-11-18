node {
    try{
    notifyBuild()
	properties([
        parameters(
            [string(defaultValue: '/var/site/typhon-ql', name: 'UPDATE_SITE_PATH')]
        )
    ])  
    configFileProvider(
        [configFile(fileId: 'MyGlobalSettings', variable: 'MAVEN_SETTINGS')]) {
        sh 'mvn -s $MAVEN_SETTINGS clean package'
    }
    stage('Clone') {
        checkout scm
    }

    stage('Build bundle') {
        sh 'cd typhonql-bundler && mvn clean install'
    }

    stage('Build typhonql') {
	    sh 'mvn -gs ${MAVEN_SETTINGS} clean package deploy'
    }

    stage('Deploy update site') {
		sh "rm -rf ${UPDATE_SITE_PATH}"
		sh "mkdir ${UPDATE_SITE_PATH}"
        sh "cp -a typhonql-update-site/target/. ${UPDATE_SITE_PATH}/"
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
