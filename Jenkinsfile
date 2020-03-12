node {
  env.JAVA_HOME="${tool 'adopt-openjdk8'}"
  env.PATH="${env.JAVA_HOME}/bin:${env.PATH}"
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
        	sh 'cd typhonql-server && mvn -U -B -gs $MAVEN_SETTINGS clean test'
        }
    }

    stage('Deploying') {
        if (env.BRANCH_NAME == "master") {
            configFileProvider(
                [configFile(fileId: 'c262b5dc-6fc6-40eb-a271-885950d8cf70', variable: 'MAVEN_SETTINGS')]) {
                sh 'cd typhonql-bundler && mvn -U -B -gs $MAVEN_SETTINGS deploy'
                sh 'mvn -U -B -gs $MAVEN_SETTINGS -pl \'!typhonql-update-site\' deploy'
            }
        }

    }
    stage('Deploy update site') {
        if (env.BRANCH_NAME == "master") {
            sh 'mvn -B -gs $MAVEN_SETTINGS package'
            sh "rm -rf ${UPDATE_SITE_PATH}"
            sh "mkdir ${UPDATE_SITE_PATH}"
            sh "cp -a typhonql-update-site/target/. ${UPDATE_SITE_PATH}/"
        }
    }
    stage('Deploying server') {
        if (env.BRANCH_NAME == "master") {
            configFileProvider(
                    [configFile(fileId: 'c262b5dc-6fc6-40eb-a271-885950d8cf70', variable: 'MAVEN_SETTINGS')]) {
                withCredentials([usernamePassword(credentialsId: 'swateng-typhonbuild', usernameVariable: 'REGISTRY_USERNAME', passwordVariable: 'REGISTRY_PASSWORD')]) {
                    sh 'cd typhonql-server && mvn -U -B -gs $MAVEN_SETTINGS clean compile jib:build'
                }
            }
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
