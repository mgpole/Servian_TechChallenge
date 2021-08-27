# Servian DevOps Tech Challenge
This code deploys the Servian Tech Challenge "Todo" app into an Azure environment.

# Overview
![Azure ToDo app overview](/doc/img/azure_diagram.png "Azure Diagram")

The Tech Challenge “ToDo” runs on native Azure PaaS services to deliver a highly available and scalable application. The main resources used in this solution are Azure App Services, PostgreSQL and Container Instances.
The solution is designed to be deployed via Azure DevOps Pipelines from a Terraform IaC template stored in a Git repository.

## App Services
Azure App services runs the web front-end Docker container on an App Service Plan. The container is pulled directly from Docker Hub.
Auto-scaling is enabled on the app service plan to dynamically scale up and down instances depending on load.  
Standard or premium hosting plans SKU’s are required in order to support VNet integration.

## PostgreSQL
Azure Database for PostgreSQL hosts the backend database for the application.
General purpose SKU is required in order to support VNet integration.

## Container Instance
Azure Container Instance is used to run a container that initialises the database and populates with test data. This container is only intended to run-once when the solution is deployed or when the database is to be refreshed. 
The container image is pulled directly from docker hub.

## Virtual Network
Azure Virtual Network is deployed to provide isolated access to the backend PostgreSQL database. Two subnets are provisioned in the solution, one for the front end app service and the other for the container instance. Each subnet has a SQL DB service endpoint enabled. 
Virtual network rules are configured on PostgreSQL to allow only the web and container subnets access to the SQL server. 

# Azure DevOps Pipeline Deployment

## Requirements
The solution requires the following in place for deployment.
- Azure Subscription
- Azure DevOps project
- Environments configured in DevOps Pipelines
- Environment variable group with populated values for *db_admin_login* and *db_admin_password* variables
- AzureAD Service principal with contributor access to the Azure subscription used for deployment. (This is configured as a service connection in the Azure DevOps project.)
- Provisioned storage account for Terraform state file. (The deployment will create a new container and state file within this storage account)

## Environments
The deployment pipeline is configured to deploy the solution through various environments as required (dev → test → prod) via pipeline stages. 

Environment(s) need to be provisioned before the pipeline is run.

![Azure DevOps Pipeline Environments](/doc/img/devops_environments.png "DevOps Environments")

## Environment Variables
The following environment variables are used throughout the deployment to ensure consistent naming of resources. When passed through to terraform these variables are in UPPERCASE.

- environment_name
- product_name

## Variable Groups
Variable groups for each environment need to be populated for the pipeline to reference. *db_admin_login* and *db_admin_password* are stored as sensitive variables and passed to the pipeline when running. 
The variable group needs to be named as follows **<product_name>-<environment_name>-lib**. For example *todo-dev-lib*.

![Azure DevOps Pipeline Variable Group](/doc/img/devops_variable_group.png "DevOps Variables")

## Terraform Environment Variables
Terraform environment variables for each environment are stored in **<environment_name>.tfvars** file. A separate *.tfvars* file is required for each environment.

## Pipeline Setup
1. Configure required pipeline environments.
2. Configure pipeline variable groups for each environment.
3. Update stage parameters in **main_pipeline.yml** file with environment name and service connection name. 
    a. environment_name:<env> 
    b. arm_service_connection:<service connection name>
4. Update **global_variables.yml** with required values for product name and terraform storage account details. 
    a. product_name: <product name>
    b. trf_state_rg: <storage account resource group> 
    c. trf_state_acc: <storage account name> 
    d. trf_location : <storage account location> 
5. Create a new Azure DevOps pipeline referencing main_pipeline.yml file. 
6. Run the pipeline to deploy the solution. 

## Access the Application
Access the application by browsing to the app service web endpoint. - https://<environment_name>-<product>-web.azurewebsites.net

For example - *https://dev-todo-web.azurewebsites.net*

# Design Notes

## Creating SQL DB from Terraform
The SQL DB is required to be created via Terraform due to an error with Azure PostgreSQL and the username format (user@servername). This is documented [here](https://github.com/servian/TechChallengeApp/issues/49). 
Once the DB is created the container instance initialises the DB with the command `./TechChallengeApp updatedb -s` 

## App Service secure variables
Secure connection string variables for Azure App Service can be used however these have a custom prefix. The app expects all variables to use the prefix `VTT_` therefore standard app settings are used and variables passed in plan text.
Application code would need to be updated to use Azure App Service secure connection string variables. 