# Wisecow on Kubernetes — Containerised Deployment with End-to-End TLS

Containerises the **Wisecow** app — a tiny Bash HTTP server that serves `fortune | cowsay` — and deploys it to Kubernetes behind an NGINX Ingress with an automatically issued and renewed TLS certificate from cert-manager.

Built as a DevOps assessment task: take an application that was never designed to be containerised, and get it running on Kubernetes properly — image, deployment, service, ingress, and a real certificate.

## Why this exists

Wisecow is deliberately awkward. It is a shell script that uses `mkfifo` and `netcat` to speak raw HTTP on port 4499. That makes it a good exercise in the part of containerisation people usually skip: getting a non-cloud-native process to behave as a well-mannered Kubernetes workload with a stable service endpoint and working HTTPS.

## Architecture

```
Internet
   |  https://<your-host>
   v
NGINX Ingress  ---- TLS terminated, secret: wisecow-tls
   |  :80                         ^
   v                              |
Service (wisecow-service)    cert-manager issues + renews
   |  :4499
   v
Deployment pods --> wisecow.sh (fortune | cowsay over netcat)
```

## What is in here

| File | Purpose |
| --- | --- |
| `wisecow.sh` | The application — a Bash HTTP server on port 4499 |
| `dockerfile` | Ubuntu base plus `cowsay`, `fortune`, `netcat`; runs the script as entrypoint |
| `wisecow-deployment.yml` | Kubernetes Deployment |
| `wisecow-service.yaml` | Service exposing the pods on port 80 to container 4499 |
| `wisecow-ingress.yml` | NGINX Ingress with forced SSL redirect and TLS host |
| `cluster-issuer.yml` | cert-manager `ClusterIssuer` (ACME / Let us Encrypt) |
| `certificate.yml` | `Certificate` resource that produces the `wisecow-tls` secret |

## Prerequisites

- A Kubernetes cluster and `kubectl` pointed at it
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/) installed
- [cert-manager](https://cert-manager.io/docs/installation/) installed
- A DNS A record pointing your hostname at the ingress controller external IP
- Docker, and a registry you can push to

## Deploy

**1. Build and push the image**

```bash
docker build -t <your-registry>/wisecow:latest -f dockerfile .
docker push <your-registry>/wisecow:latest
```

**2. Point the manifests at your environment**

- Update the image reference in `wisecow-deployment.yml`
- Replace the hostname in `wisecow-ingress.yml` and `certificate.yml`
- Set your ACME contact email in `cluster-issuer.yml`

**3. Apply**

```bash
kubectl apply -f cluster-issuer.yml
kubectl apply -f wisecow-deployment.yml
kubectl apply -f wisecow-service.yaml
kubectl apply -f certificate.yml
kubectl apply -f wisecow-ingress.yml
```

**4. Verify**

```bash
kubectl get pods,svc,ingress
kubectl get certificate          # READY should become True
curl https://<your-host>/
```

You should get an ASCII cow telling you something.

## Run it locally instead

```bash
docker build -t wisecow -f dockerfile .
docker run --rm -p 4499:4499 wisecow
curl localhost:4499
```

## Notes

- The certificate only issues once DNS resolves to the ingress — ACME HTTP-01 has to reach the host. `kubectl describe certificate wisecow-tls` explains any failure.
- The `dockerfile` keeps a few `which` and `ls` diagnostic layers from bring-up. They are harmless, but drop them for a leaner image.
- `library/ubuntu:latest` is intentionally unpinned here. Pin a digest for anything you actually run long term.
- The app is single-connection by design (`mkfifo` plus one `nc` loop). It is a demo workload, not something to load-test.
