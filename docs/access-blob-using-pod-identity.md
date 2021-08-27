# Access Blob using Pod Identity

In this example, we will be assigning user assigned identity to a pod which will be used to download a blob from Azure storage.

- Set environment defaults.

```sh
SUBSCRIPTION_ID=<my-subsscription-id>
RESOURCE_GROUP=<my-aks-rg>
LOCATION=eastus2
CLUSTER_NAME=<my-aks-cluster>
```

- Create a general-purpose storage account and a blob container 

```sh
STORAGE_ACCOUNT=<my-storage>
CONTAINER=<my-container>
az storage account create \
    --resource-group $RESOURCE_GROUP \
    --name $STORAGE_ACCOUNT \
    --location $LOCATION \
    --encryption-services blob
az storage container create  \
    --name $CONTAINER \
    --account-name $STORAGE_ACCOUNT
```

- Uploade test blob to storage container.

```sh
BLOB_NAME=index.html
az storage blob upload \
    --container-name $CONTAINER \
    --name $BLOB_NAME \
    --file /blobs/index.html 
```
 
- Create an user assigned identity for retreiving blob from Azure Storage.

```sh
IDENTITY=<my-blob-identity>
az identity create \
    --resource-group $RESOURCE_GROUP \
    --name $IDENTITY
PRINCIPAL_ID=$(az identity show --resource-group $RESOURCE_GROUP  --name $IDENTITY --query 'principalId' -o tsv)
```

- Assign permission for user assigned identity to access blob container.

```sh
az role assignment create \
    --assignee $PRINCIPAL_ID \
    --role 'Storage Blob Data Reader' \
    --scope '/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT'
```

- Create pod identity for the cluster using `az aks pod-identity add` command.

```sh
az aks pod-identity add --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --namespace 'nginx-blob-test'  \
    --name 'blob-identity' \
    --identity-resource-id '/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY'
```

- Deploy `manifests/nginx-blob-test.yaml` to create a sample app which retrieves a blob from Azure Storage using pod identity.

```sh
kubectl apply -f manifests/nginx-blob-test.yaml
```

- Check whether the `nginx-blob-test` app is running.

```sh
kubectl get all -n nginx-blob-test
```

- Run a test pod to check whether nginx `index.html` blob is downloaded from Azure Storage and returned by `nginx-blob-test` service.

```sh
kubectl run -it --rm busybox --image=radial/busyboxplus:curl -n nginx-blob-test -- sh

[ root@busybox:/ ]$ curl http://nginx-blob-test
<!DOCTYPE html>
<html>

<head>
    <title>Welcome to AKS Pod Identity !</title>
    <style>
        html {
            color-scheme: light dark;
        }

        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
</head>

<body>
    <h1>Welcome to AKS Pod Identity !</h1>
    <p>If you see this page, AKS pod is successfully authenticated to Azure Blob Storage
        using Pod Identity and downloaded the static content.</p>

    <p>For online documentation and support please refer to
        <a href="https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity/">docs.microsoft.com</a>.
    </p>

    <p><em>Thank you for using AKS Pod Identity.</em></p>
</body>

</html>[ root@busybox:/ ]$ exit
```

- Inspect the `nginx-blob-test` pod to check whether `index.html` blob is created as a file in `/usr/share/nginx/html/` path.

```sh
kubectl exec -it -n nginx-blob-test $(kubectl get pods -n nginx-blob-test -l app=nginx-blob-test -o jsonpath='{.items[0].metadata.name}') -- sh

/ # cd /usr/share/nginx/html/
/usr/share/nginx/html # ls
index.html
/usr/share/nginx/html # cat index.html
<!DOCTYPE html>
<html>

<head>
    <title>Welcome to AKS Pod Identity !</title>
    <style>
        html {
            color-scheme: light dark;
        }

        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
</head>

<body>
    <h1>Welcome to AKS Pod Identity !</h1>
    <p>If you see this page, AKS pod is successfully authenticated to Azure Blob Storage
        using Pod Identity and downloaded the static content.</p>

    <p>For online documentation and support please refer to
        <a href="https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity/">docs.microsoft.com</a>.
    </p>

    <p><em>Thank you for using AKS Pod Identity.</em></p>
</body>

</html>/usr/share/nginx/html # exit
```

# Cleanup

- Uninstall App 

```sh
kubectl delete ns nginx-blob-test
```

- Delete resource group

```sh
az group delete --name $RESOURCE_GROUP
```