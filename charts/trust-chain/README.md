# Trust Chain Helm Chart

This chart deploys Trust Chain resources to a Kubernetes cluster.

> The implementation of the Helm chart is the bare minimum.
> The Helm Chart is not meant to be infinitely configurable, but to provide a quick way to deploy Trust Chain to a Kubernetes cluster.

## Usage in Teknoir platform
Use the HelmChart to deploy the Trust Chain resources to a Teknoir Cluster.

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: trust-chain
  namespace: teknoir-system
spec:
  repo: https://teknoir.github.io/trust-chain-helm
  chart: trust-chain
  targetNamespace: teknoir-system
  valuesContent: |-
    # Example for minimal configuration
    
```

## Adding the repository

```bash
helm repo add teknoir-trust-chain https://teknoir.github.io/trust-chain-helm/
```

## Installing the chart

```bash
helm install trust-chain teknoir-trust-chain/trust-chain -f values.yaml
```

## Important

> Security: Keep the root key tightly controlled (ideally offline/out of the cluster); use the intermediate for everyday 
> issuance. (If you already have an external root, you can also import it as the secretName for a CA issuer and skip 
> bootstrapping the root in-cluster.)


## Usage

Create a Teamspace(namespace) CA and Issuer using the Intermediate CA & Issuer to have a separate CA for each namespace.

Teamspace CA:
```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{teamspace}}-ca
  namespace: {{teamspace}}
spec:
  isCA: true
  commonName: Teamspace {{teamspace}} CA
  secretName: {{teamspace}}-ca
  privateKey:
    algorithm: RSA
    size: 4096
    rotationPolicy: Never
  duration: 26280h   # ~3y
  renewBefore: 720h  # 30d
  usages:
    - cert sign
    - crl sign
    - digital signature
    - key encipherment
  issuerRef:
    name: teknoir-intermediate-ca
    kind: ClusterIssuer
```

Teamspace issuer:
```yaml
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: {{teamspace}}-ca
  namespace: {{teamspace}}
spec:
  ca:
    secretName: {{teamspace}}-ca
```

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

## Extracting JWKS from Kubernetes Secret

To generate JWKS from a Kubernetes TLS secret using openssl:

```bash
./extract-jwks.sh
```

This will save the JWKS to `./jwks/jwks.json`.
