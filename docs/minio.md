#### Cleanup previous installation

```sh
helm uninstall minio -n minio || true
kubectl delete ns minio --wait=true || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete ingress minio-ingress || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete certificate minio-tls || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete secret minio-tls || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete service minio || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete deployment minio || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete pvc minio-data || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete sa minio || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete secrets minio-root || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio get all
kubectl -n minio get service,deploy,pvc,secret
```

#### Credentials

```sh
kubectl get secret minio-root -n minio -o jsonpath="{.data.rootUser}" | base64 -d && echo
kubectl get secret minio-root -n minio -o jsonpath="{.data.rootPassword}" | base64 -d && echo
kubectl get secrets -n minio
```

#### Cluster-internal access

Minio is exposed via a `ClusterIP` service, so it is reachable only from inside the cluster. The stable DNS name is `minio.minio.svc.cluster.local` and it listens on port `9000`.

```sh
kubectl -n minio get svc minio -o jsonpath='{.spec.clusterIP}'    # to see the internal IP
```

Other pods can use the FQDN `minio.minio.svc.cluster.local:9000`. From a workstation you can temporarily expose it via port-forwarding:

```sh
kubectl -n minio port-forward svc/minio 9000:9000
```

Inside the cluster you can also curl the service from a debug pod:

```sh
kubectl -n minio run --rm -it curl --image=radial/busyboxplus:curl -- sh
curl http://minio.minio.svc.cluster.local:9000/minio/health/ready
```
