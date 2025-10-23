# Teamspace CA Helm Chart

This chart deploys Teamspace CA resources to a Kubernetes cluster namespace.

> The implementation of the Helm chart is the bare minimum.
> The Helm Chart is not meant to be infinitely configurable, but to provide a quick way to deploy Teamspace CA to a Kubernetes cluster.

## Usage in Teknoir platform
Use the HelmChart to deploy the Teamspace CA resources to a Teknoir Cluster.

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: teamspace-ca
  namespace: demonstrations
spec:
  repo: https://teknoir.github.io/trust-chain-helm
  chart: teamspace-ca
  targetNamespace: demonstrations
  valuesContent: |-
    # Example for minimal configuration
    
```

## Adding the repository

```bash
helm repo add teknoir-teamspace-ca https://teknoir.github.io/trust-chain-helm/
```

## Installing the chart

```bash
helm install teamspace-ca trust-chain-helm/teamspace-ca -f values.yaml
```

## Usage

Create a Teamspace(namespace) CA and Issuer using the Intermediate CA & Issuer to have a separate CA for each namespace.

Device cert:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{device-id}}
  namespace: {{teamspace}}
spec:
  secretName: {{device-id}}-client-cert
  commonName: {{device-id}}
  subject:
    organizations: ["Teknoir", "{{teamspace}}"]
  emailAddresses:
    - anders.aslund@teknoir.ai
  uris:
    - spiffe://{{domain}}/ns/{{teamspace}}/device/{{device-id}}
  usages:
    - digital signature
    - key encipherment
    - client auth
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
    rotationPolicy: Never
  duration: 26280h   # ~3y
  renewBefore: 720h  # 30d
  issuerRef:
    kind: ClusterIssuer
    name: teknoir-intermediate-ca
```
