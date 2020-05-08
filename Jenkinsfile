// This pipeline automatically tests a student's full homework
// environment for OpenShift Advanced Application Development Homework
// and then executes the pipelines to ensure that everything works.
//
// Successful completion of this pipeline means that the
// student passed the homework assignment.
// Failure of the pipeline means that the student failed
// the homework assignment.

// How to setup:
// -------------
// * Create a persistent Jenkins in a separate project (e.g. gpte-jenkins)
//
// * Add self-provisioner role to the service account jenkins
//   oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:gpte-jenkins:jenkins 
//
// * Create an Item of type Pipeline (Use name "OpenShift 4 Advanced Application Deployment Homework Grading")
// * Create seven Parameters:
//   - GUID (type String):            GUID to prefix all projects - use Homework Environment GUID
//   - CREDENTIAL_NAME (type String): Name of Jenkins Credential that contains the USER and PASSWORD for Gitea.
//                                    Should be the same as OpenTLC User Name
//   - REPO (type String):            Name of the private repository (do not include the hostname and user of Gitea)
//   - CLUSTER (type String):         Grading Cluster base URL. E.g. shared.na.openshift.opentlc.com
//   - SETUP (type Boolean):          Default: true
//                                    If true will create all necessary projects.
//                                    If false assumes that projects are already there and only pipelines need
//                                    to be executed.
//   - DELETE (type Boolean):         Default: true
//                                    If true will delete all created projects
//                                    after a successful run.
//   - SUBMIT_GRADE (type Boolean):   Default: false
//                                    If true will submit the result via FTL into the LMS
//                                    Currently not implemented
// * Use https://github.com/redhat-gpte-devopsautomation/ocp4_app_deploy_homework_grading as the Git Repo
//   and 'Jenkinsfile' as the Jenkinsfile.

def STUDENT_USER=""
def STUDENT_PASSWORD=""
def GITEA_HOST="homework-gitea.gpte-hw-cicd.svc.cluster.local:3000"

pipeline {
  agent {
    kubernetes {
      label "homework"
      cloud "openshift"
      inheritFrom "maven"
      containerTemplate {
        name "jnlp"
        image "image-registry.openshift-image-registry.svc:5000/gpte-jenkins/jenkins-agent-homework:latest"
        resourceRequestMemory "1Gi"
        resourceLimitMemory "2Gi"
        resourceRequestCpu "1"
        resourceLimitCpu "2"
      }
    }
  }
  stages {
    stage('Get Student Homework Repo') {
      steps {
        echo "*******************************************************************\n" +
             "*** OpenShift Advanced Application Deployment Homework Grading ***\n" +
             "*** GUID:            ${GUID}\n" +
             "*** CREDENTIAL_NAME: ${CREDENTIAL_NAME}\n" +
             "*** REPO:            ${REPO}\n" +
             "*** CLUSTER:         ${CLUSTER}\n" +
             "*** SETUP:           ${SETUP}\n" +
             "*** DELETE:          ${DELETE}\n" +
             "*******************************************************************\n"

        echo "Cloning Student Project Repository"
        // Retrieve userid and password from provided credentials
        withCredentials([usernamePassword(credentialsId: "${CREDENTIAL_NAME}", passwordVariable: 'PASSWORD', usernameVariable: 'USER')]) {
          script {
            STUDENT_USER="${USER}"
            STUDENT_PASSWORD="${PASSWORD}"
          }
        }
        // Check out repository
        git credentialsId: "${STUDENT_USER}", url: "http://${GITEA_HOST}/${STUDENT_USER}/${REPO}"

        // Ensure all shell scripts are executable (workaround for Windows users)
        sh "chmod +x ./bin/*.sh"

        // Patch Manifests to include correct GUID for image
        sh "sed -i 's/GUID/${GUID}/g' manifests/tasks-is-dev.yaml"
        sh "sed -i 's/GUID/${GUID}/g' manifests/tasks-bc-dev.yaml"
        sh "sed -i 's/GUID/${GUID}/g' manifests/tasks-dc-dev.yaml"
        sh "sed -i 's/GUID/${GUID}/g' manifests/tasks-dc-blue.yaml"
        sh "sed -i 's/GUID/${GUID}/g' manifests/tasks-dc-green.yaml"
      }
    }
    stage("Create Projects") {
      when {
        environment name: 'SETUP', value: 'true'
      }
      steps {
        echo "Creating Projects"
        sh "./bin/setup_projects.sh ${GUID} ${STUDENT_USER} true"
      }
    }
    stage("Setup Infrastructure") {
      failFast true
      when {
        environment name: 'SETUP', value: 'true'
      }
      parallel {
        stage("Setup Jenkins") {
          steps {
            echo "Setting up Jenkins"
            sh "./bin/setup_jenkins.sh ${GUID} http://${GITEA_HOST}/${STUDENT_USER}/${REPO} ${CLUSTER}"
          }
        }
        stage("Setup Development Project") {
          steps {
            echo "Setting up Development Project"
            sh "./bin/setup_dev.sh ${GUID}"
          }
        }
        stage("Setup Production Project") {
          steps {
            echo "Setting up Production Project"
            sh "./bin/setup_prod.sh ${GUID}"
          }
        }
      }
    }
    stage("Reset Projects") {
      failFast true
      when {
        environment name: 'SETUP', value: 'false'
      }
      steps {
        sh "./bin/reset_prod.sh ${GUID}"
      }
    }
    stage("First Pipeline Run (from Green to Blue)") {
      steps {
        echo "Executing Initial Tasks Pipeline - BLUE deployment"
        script {
          openshift.withCluster() {
            openshift.withProject("${GUID}-jenkins") {
              openshift.selector("bc", "tasks-pipeline").startBuild("--wait=true")
            }
          }
        }
      }
    }
    stage('Test Tasks in Dev') {
      steps {
        echo "Testing Tasks Dev Application"
        script {
          def devTasksRoute = sh(returnStdout: true, script: "curl tasks-${GUID}-tasks-dev.apps.${CLUSTER}").trim()
          // Check if the returned string contains "tasks-dev"
          if (devTasksRoute.contains("tasks-dev")) {
            echo "*** tasks-dev validated successfully."
          }
          else {
            error("*** tasks-dev returned unexpected name.")
          }
        }
      }
    }
    stage('Test Blue Services in Prod') {
      steps {
        echo "Testing Prod Services (BLUE)"
        script {
          def tasksRoute = sh(returnStdout: true, script: "curl tasks-${GUID}-tasks-prod.apps.${CLUSTER}").trim()
          // Check if the returned string contains "tasks-blue"
          if (tasksRoute.contains("tasks-blue")) {
            echo "*** tasks-blue validated successfully."
          }
          else {
            error("*** tasks-blue returned unexpected name.")
          }
        }
      }
    }
    stage("Second Pipeline Run (from Blue to Green)") {
      steps {
        echo "Executing Second Tasks Pipeline - GREEN deployment"
        script {
          openshift.withCluster() {
            openshift.withProject("${GUID}-jenkins") {
              openshift.selector("bc", "tasks-pipeline").startBuild("--wait=true")
            }
          }
        }
      }
    }
    stage('Test Green Parksmap in Prod') {
      steps {
        echo "Testing Prod Parksmap Application (GREEN)"
        script {
          def tasksRoute = sh(returnStdout: true, script: "curl tasks-${GUID}-tasks-prod.apps.${CLUSTER}").trim()
          // Check if the returned string contains "tasks-green"
          if (tasksRoute.contains("tasks-green")) {
            echo "*** tasks-green validated successfully."
          }
          else {
            error("*** tasks-green returned unexpected name.")
          }
        }
      }
    }
    stage('Cleanup') {
      when {
        environment name: 'DELETE', value: 'true'
      }
      steps {
        echo "Cleanup - deleting all projects for GUID=${GUID}"
        sh "./bin/cleanup.sh ${GUID}"
      }
    }
  }
}
