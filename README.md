# Activity 2

Create a container that runs NGINX to host a website that embeddeds a Nyan Cat YouTube Video.

# Steps

## Fork

Fork this repository in GitLab so you have your own copy to work in:

1. Open the original repository in the GitLab UI.
2. Click **Fork** (top-right) and select your personal namespace or group as the destination.
3. Clone your fork locally:

   ```bash
   git clone <URL-of-your-fork>.git
   cd activity2
   ```

## Create an HTML file

Create `www/index.html` that embeds a Nyan Cat YouTube video. The repository already
contains a ready-to-use example at [`www/index.html`](www/index.html). It uses the
classic Nyan Cat video (`QH2-TGUlwu4`) and a responsive, centered layout:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nyan Cat</title>
    <style>
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #ff6ec7, #a0e6ff);
        }
        .container { text-align: center; padding: 2rem; background: rgba(255,255,255,0.85); border-radius: 16px; box-shadow: 0 4px 24px rgba(0,0,0,0.35); }
        .video-wrapper {
            position: relative; width: 640px; max-width: 90vw; aspect-ratio: 16 / 9; overflow: hidden; border-radius: 8px; box-shadow: 0 2px 32px rgba(0,0,0,0.4);
        }
        .video-wrapper iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Nyan Cat</h1>
        <div class="video-wrapper">
            <iframe
                src="https://www.youtube.com/embed/QH2-TGUlwu4"
                title="Nyan Cat original"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                referrerpolicy="strict-origin-when-cross-origin"
                allowfullscreen>
            </iframe>
        </div>
    </div>
</body>
</html>
```

## Create a GitLab CI/CD file

The repository includes [`.gitlab-ci.yml`](.gitlab-ci.yml), which builds and pushes the
NGINX container image to the GitLab Container Registry using Kaniko, then leaves a
placeholder deploy job for Rancher. The pipeline has three stages:

1. **build** – build the Docker image from the `Dockerfile`.
2. **push** – push commit-SHA and `latest` tags to `$CI_REGISTRY_IMAGE`.
3. **deploy** – roll out the new image (configure this job for your cluster).

The pipeline uses these built-in CI/CD variables, so no secrets need to be added manually:

| Variable | Meaning |
| --- | --- |
| `CI_REGISTRY` | Container registry host (`gitlab.com`) |
| `CI_REGISTRY_IMAGE` | Full image path `<registry>/<group>/<project>` |
| `CI_REGISTRY_USER` / `CI_REGISTRY_PASSWORD` | Registry credentials (auto-set) |

### Required variables for Rancher/cluster access

The `deploy` job needs a kubeconfig so it can talk to your cluster. Add a masked,
protected CI/CD variable named **`KUBECONFIG`** containing the contents of your
kubeconfig file (`Settings > CI/CD > Variables`). The deploy script then uses it:

```yaml
deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  variables:
    KUBECONFIG: /tmp/.kube/config
  before_script:
    - mkdir -p /tmp/.kube
    - echo "$KUBECONFIG" > /tmp/.kube/config
  script:
    - kubectl set image deployment/nyan-cat nginx="$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" -n activity2
```

## Deploy with Rancher

HTTPS is terminated at the ingress, so the container only needs to serve plain HTTP on port 80.
The target URL / host for this assignment is:

```
cis-yournetid.student.hpc.fau.edu   # replace yournetid with your actual netid
```

There are two common ways to deploy through Rancher.

### Option A — Rancher UI (simplest)

1. **Import the cluster** into Rancher (`Cluster Management > Import`), or select an existing one.
2. Create a namespace, e.g. `activity2`, from **Cluster Explorer**.
3. **Deploy the workload:**
   - Go to **Workload > Create**, choose *Single container*.
   - Image: your registry image (e.g. `registry.gitlab.com/<group>/<project>:latest`).
   - Add a container port `80` → Host IP/port `80`.
   - Set the Service Account / image pull secret if using a private registry (`Container Registry` credentials).
4. **Create an Ingress:**
   - Go to **Service Discovery > Ingresses > Create**.
   - Rule: host = `cis-yournetid.student.hpc.fau.edu`, path `/`, target service/port = your workload, port `80`.
   - Enable TLS (Rancher can auto-provision a certificate via cert-manager / Let's Encrypt if configured).

### Option B — kubectl manifests + Rancher

Apply plain Kubernetes manifests to the cluster managed by Rancher:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nyan-cat
  namespace: activity2
spec:
  replicas: 3
  selector:
    matchLabels: { app: nyan-cat }
  template:
    metadata:
      labels: { app: nyan-cat }
    spec:
      containers:
        - name: nginx
          image: registry.gitlab.com/<group>/<project>:latest   # or $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA via CI
          ports: [{ containerPort: 80 }]

---
apiVersion: v1
kind: Service
metadata:
  name: nyan-cat-svc
  namespace: activity2
spec:
  selector: { app: nyan-cat }
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nyan-cat-ingress
  namespace: activity2
spec:
  ingressClassName: nginx            # adjust to the class Rancher uses on your cluster
  rules:
    - host: cis-yournetid.student.hpc.fau.edu   # replace yournetid with your netid
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nyan-cat-svc
                port: { number: 80 }

---
apiVersion: networking.k8s.io/v1
kind: IngressTLS
# Optional: add TLS if cert-manager is configured for the domain.
metadata:
  name: nyan-cat-tls
```

Apply with `kubectl apply -f manifests.yaml` (with your kubeconfig), then verify:

```bash
kubectl get pods,svc,ingress -n activity2
curl -k https://cis-yournetid.student.hpc.fau.edu   # should return the Nyan Cat page
```

## Local testing (optional)

Validate the pipeline locally before pushing anything to GitLab using
[`gitlab-ci-local`](https://github.com/firecow/gitlab-ci-local), which runs your real
`.gitlab-ci.yml` jobs in Docker on your machine.

```bash
# Install once (Homebrew or npm)
brew install gitlab-ci-local      # or:  npm install -g gitlab-ci-local

./test.sh            # validate YAML + run lint-workflow, then build & serve the image
./test.sh list       # print all jobs/stages and validate the YAML
./test.sh lint       # run only the self-contained lint-workflow job
./test.sh build      # host-side Docker build + curl validation (no gitlab-ci-local)

docker build -t nyan-cat .
docker run --rm -p 8080:80 nyan-cat
# Open http://localhost:8080 in a browser.
```

> The `test-workflow`/build/deploy steps need an image builder inside the job container
> (Docker-in-Docker). That is blocked on Rancher Desktop and some Docker Desktop setups,
> so `test.sh` runs those checks directly against the host's docker daemon as a faithful
> fallback — no privileged mode required.
