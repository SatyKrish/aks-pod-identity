# AKS Pod Identity

AKS Pod Identity uses `Kubernetes` primitives to associate User Managed Identity with a pod, that allow containerized workload to authenticate with Azure Services

## Overview

AKS Pod Identity Add-on enables containerized applications in AKS cluster to access services that uses Azure Active Directory (AAD) as an identity provider.

In AKS, following component is deployed to allow pods to use user managed identities:

- The **Node Management Identity (NMI) server** is a pod that runs as a DaemonSet on each node in the AKS cluster. The NMI server listens for pod requests to Azure services.

In the following example, we create a pod that uses a user managed identity to request access token. Application can use that token to access any service integrated with Azure Active Directory:

![AKS Pod Identity Flow](docs/img/aks-pod-identity-flow.png)

1. Cluster operator first creates identity used by pods to request access to services.
2. The NMI server relay any pod requests for access tokens to Azure AD.
3. A developer deploys a pod with user managed identity that requests an access token through the NMI server.
4. The token is returned to the pod and used to access Azure resources

> For more details, refer [AAD Pod Identity](https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity/) Microsoft documentation.

## Prerequisites

You must have the following resource installed:

- The Azure CLI, version 2.20.0 or later
  ```sh
  curl -L https://aka.ms/InstallAzureCli | bash
  ```

- The aks-preview extension version 0.5.5 or later
  ```sh
  # Install the aks-preview extension
  az extension add --name aks-preview

  # Update the extension to make sure you have the latest version installed
  az extension update --name aks-preview
  ```

  ```sh
  OUPUT:
  $ az version
  {
    "azure-cli": "2.20.0",
    "azure-cli-core": "2.20.0",    
    "azure-cli-telemetry": "1.0.6",
    "extensions": {
      "aks-preview": "0.5.10",     
      "connectedk8s": "1.1.3"      
    }
  }
  ```

## Register `EnablePodIdentityPreview` Feature

Pod Identity is a preview feature and has to be `registered` before use.

```sh
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
```

It takes a few minutes for the status to show Registered. You can check on the registration status using the `az feature list` command:

```sh
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnablePodIdentityPreview')].{Name:name,State:properties.state}"
```

When ready, refresh the registration of the Microsoft.ContainerService resource provider using the az provider register command:

```sh
az provider register --namespace Microsoft.ContainerService
```

## Create AKS cluster with Pod Identity Add-on 

- Set environment defaults.

```sh
SUBSCRIPTION_ID=<my-subsscription-id>
RESOURCE_GROUP=<my-aks-rg>
LOCATION=eastus2
CLUSTER_NAME=<my-aks-cluster>
```

- Create an AKS cluster with CNI, managed identity and pod identity add-on enabled. 

```sh
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-managed-identity \
  --enable-pod-identity \
  --network-plugin azure
```

- Verify whether pod identity add-on enabled.

```sh
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query 'podIdentityProfile.enabled'

OUTPUT:
true
```

- Generate `kubeconfig` to connect to the AKS cluster.

```sh
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --admin
```
## Scenarios

- [Access Azure Blob Storage using Pod Identity](docs/access-blob-using-pod-identity.md)