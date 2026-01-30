# Jellyfin ArgoCD Troubleshooting Summary (2026-01-18)

## Goal & Environment
- Goal: Deploy a Jellyfin server via ArgoCD using Helm; expose via `ingress-nginx-apps`; restrict access to internal network; support WebOS client; use local path storage.
- Environment: Single-node Kubernetes; ArgoCD; ingress controller using hostPorts; internal network `192.168.100.*`; node IP `192.168.100.22`.

## Problems & Symptoms
- ArgoCD sync error: namespace missing.
- ArgoCD Helm error: chart not found.
- Ingress access control concerns when traffic comes through external reverse proxy.
- Storage plan change: no NFS available; use local path for config/cache/media.
- Port mapping clarity: service on 80, container on 8096; ingress/backend alignment.

## Chronological Actions, Commands, Results
- Reviewed ArgoCD app and values.
  - Files: [apps/jellyfin/application.yaml](apps/jellyfin/application.yaml), [apps/jellyfin/values.yaml](apps/jellyfin/values.yaml)
- Created ingress for Jellyfin with hostname and ingressClass; initially whitelisted internal subnet.
  - File: [apps/jellyfin/ingress.yaml](apps/jellyfin/ingress.yaml)
- Switched media storage from NFS to local path.
  - Change: [apps/jellyfin/values.yaml](apps/jellyfin/values.yaml) `persistence.media.storageClass: local-path`, `accessMode: ReadWriteOnce`.
- Created local storage PVs and annotated folders to create.
  - File: [apps/jellyfin/storage.yaml](apps/jellyfin/storage.yaml)
- Labeled single node for scheduling Jellyfin.
  - Commands:
    ```bash
    kubectl get nodes
    kubectl label nodes <node-name> jellyfin=true
    kubectl get nodes --show-labels | grep jellyfin
    ```
  - Expected: Node labeled `jellyfin=true`; Actual: label visible in `--show-labels` output.
- Prepared local directories and permissions for PVs.
  - Commands:
    ```bash
    sudo mkdir -p /var/lib/jellyfin/{config,cache,media}
    sudo chown -R 1000:1000 /var/lib/jellyfin
    sudo chmod -R 755 /var/lib/jellyfin
    ```
  - Expected: Directories exist with UID/GID 1000 per securityContext; Actual: commands completed without error.
- Applied storage resources.
  - Commands:
    ```bash
    kubectl apply -f apps/jellyfin/storage.yaml
    kubectl get storageclass
    kubectl get pv
    ```
  - Expected: `local-path` storage class present; PVs Available then Bound after PVC creation; Actual: verified via `kubectl get pv`.
- ArgoCD sync error: namespace not found.
  - Error: “namespaces "media" not found (retried 5 times)”
  - Fix: Added namespace manifest.
  - File: [apps/jellyfin/namespace.yaml](apps/jellyfin/namespace.yaml)
  - Command (context check):
    ```bash
    kubectl get endpoints -A
    ```
  - Clue: Missing `media` namespace prevented object creation; manifest ensures creation despite `CreateNamespace=true` timing.
- ArgoCD Helm error: missing Chart.yaml.
  - Error: “error reading helm chart ... apps/jellyfin/Chart.yaml: no such file or directory”
  - Fix: Added minimal Helm chart and templates.
  - Files:
    - [apps/jellyfin/Chart.yaml](apps/jellyfin/Chart.yaml)
    - [apps/jellyfin/templates/deployment.yaml](apps/jellyfin/templates/deployment.yaml)
  - Clue: With `helm:` configured in ArgoCD, Helm expects `Chart.yaml` and only processes files under `templates/`.
- Kept Helm; moved other manifests under `templates/` (advised).
  - Suggested commands:
    ```bash
    mv apps/jellyfin/namespace.yaml apps/jellyfin/templates/
    mv apps/jellyfin/ingress.yaml apps/jellyfin/templates/
    mv apps/jellyfin/storage.yaml apps/jellyfin/templates/
    ```
- Port alignment and configurability.
  - Service external port set to 80; container port configurable via values.
  - Changes:
    - [apps/jellyfin/values.yaml](apps/jellyfin/values.yaml): `service.port: 80`, `service.containerPort: 8096`.
    - [apps/jellyfin/templates/deployment.yaml#L10](apps/jellyfin/templates/deployment.yaml#L10): `targetPort: {{ .Values.service.containerPort }}`.
    - [apps/jellyfin/templates/deployment.yaml](apps/jellyfin/templates/deployment.yaml): container `ports` uses `{{ .Values.service.containerPort }}`.
  - Clue: Jellyfin listens on 8096; templating ensures consistency while exposing service on 80.
- Ingress adjustments: removed whitelist; set backend to service port 80.
  - File: [apps/jellyfin/ingress.yaml](apps/jellyfin/ingress.yaml)
- External reverse proxy with hostPorts ingress.
  - External nginx forwards wildcard to `192.168.100.22:80`.
  - Key header to preserve client IP:
    ```nginx
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    ```
  - Optionally add ingress `use-forwarded-headers` if re-enabling IP controls.

## Configuration Changes & Rationale
- [apps/jellyfin/ingress.yaml](apps/jellyfin/ingress.yaml): Host `jellyfin.essenov.com`, `ingressClassName: ingress-nginx-apps`, backend port 80; removed whitelist to avoid blocking behind external proxy.
- [apps/jellyfin/values.yaml](apps/jellyfin/values.yaml): Local-path storage for media; service port 80; `service.containerPort` 8096 for clarity.
- [apps/jellyfin/storage.yaml](apps/jellyfin/storage.yaml): PVs targeting local directories; comments indicate folders to create and purpose.
- [apps/jellyfin/namespace.yaml](apps/jellyfin/namespace.yaml): Ensures `media` namespace exists to avoid ArgoCD timing issues.
- [apps/jellyfin/Chart.yaml](apps/jellyfin/Chart.yaml) and [apps/jellyfin/templates/deployment.yaml](apps/jellyfin/templates/deployment.yaml): Helm chart added to satisfy ArgoCD’s Helm source; templates use values for ports and resources.

## Final State & Next Actions
- Helm-based Jellyfin app prepared; namespace and storage manifests present; ingress configured for hostPorts; service port 80 → container 8096.
- External nginx proxies traffic to node IP:80; WebOS client connects via `http://jellyfin.essenov.com` internally or via external proxy.

Next actions:
```bash
kubectl get ns
kubectl get svc -n media
kubectl get deploy -n media
kubectl get pvc,pv -n media
kubectl get nodes -o wide
curl -I http://jellyfin.essenov.com
```
- Optional: Add TLS via external nginx or cert-manager; enable ArgoCD sync backoff; verify `/dev/dri` on node; confirm `local-path` provisioner availability.
