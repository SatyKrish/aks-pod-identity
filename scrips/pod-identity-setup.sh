# Install/Update AZ Cli to latest version
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Register AKS provider
az provider register --namespace Microsoft.ContainerService

# Add/Update AKS preview 
az extension add --name aks-preview
az extension update --name aks-preview

# Ensure AKS preview version is "0.4.68" or higher
az extension get --name aks-preview

# Enable Pod Identity preview
az feature register --namespace Microsoft.ContainerService -n EnablePodIdentityPreview

# Ensure Pod Identity preview state is "Registered"
az feature show --namespace Microsoft.ContainerService -n EnablePodIdentityPreview

# Register AKS provider again to propagate Pod Identity preview
az provider register -n Microsoft.ContainerService

# Enable Pod Identity in AKS cluster
az aks update -g <aks-cluster-rg> -n <aks-cluster-name> --enable-pod-identity

# Verify NMI pods are running on every node under "kube-system" namespace
kubectl get pods -A -o wide

# Add Pod Identity to AKS cluster
az aks pod-identity add -n <pod-identity-name> \
    --namespace <app-namespace> \
    --identity-resource-id '/subscriptions/<subscription-id>/resourceGroups/<identity-rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>' \
    -g <aks-cluster-rg> \
    --cluster-name <aks-cluster-name>

# Verify whether Pod Identity created
kubectl get azureidentity <pod-identity-name> -n <app-namespace> -o yaml
kubectl get azureidentitybinding <pod-identity-name> -n <app-namespace> -o yaml

# Test Pod Identity with sample app
cat << EOF | kubectl apply -f -apiVersion: v1
kind: Namespace
metadata:
  name: <app-namespace>
  labels:
    app: pod-identity-test
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-identity-test
  namespace: <app-namespace>
  labels:
    app: pod-identity-test
    aadpodidbinding: demo-identity  # specify the selector defined in AzureIdentityBinding

spec:
  containers:
    - name: test
      image: busyboxplus:curl
      command: ["/bin/sh", "-ec", "while :; do echo 'running...'; sleep 30 ; done"]
      resources:
        requests: # minimum resources required

          cpu: 125m
          memory: 128Mi
        limits: # maximum resources allocated

          cpu: 250m
          memory: 256Mi
  restartPolicy: Never
EOF

kubectl exec -i pod-identity-test -n <app-namespace> -- sh

curl -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com/&client_id=<managed-identity-client-id>"