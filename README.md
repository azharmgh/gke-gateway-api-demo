# gke-gateway-api-demo


This repository is intended to be a compainion for those who are trying to understand the GKE gateway API [Gateway concepts](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api). 

This repo has bash scripts that will help in creating the necessary google resources as mentioned in the following example: [Deploying Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways) from Google. 


## How to use this repository:
1. Create a Google Cloud Account and a new Google Cloud Project (note down the project ID).
2. Open google cloud shell for the newly created project.  
3. Clone this repository:
    - `git clone https://github.com/azharmgh/gke-gateway-api-demo.git` 
    - `cd gke-gateway-api-demo`
4. Start reading the article [Deploying Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways)
5. Run the script to start creating google resources that are mentioned in the article. 
    - `./gke-gateway-deploy.sh PROJECT-ID`
    where PROJECT-ID is your google project ID
6. The bash script will start creating resources as mentioned in the google example and will pause at key stages so you can experiment with the resources created so far and also give you time to read and understand the example. 
7. Some resources take some time to deploy, so be patient and perform a manual check to validate the creation of resources. 
8. Once you are done with the demo. you can run the following script to delete all resources: 
    - `./delete-gke-gateway.sh`
9. When you run the delete scirpt , you will be asked to manually delete the load balancers from the web console. 
10. Delete the Google Project.  
