#### Drop

```sh
helm uninstall minio -n minio || true
kubectl delete ns minio --wait=true || true
```

#### Get secrets

```sh
kubectl get secret minio -n minio -o jsonpath="{.data.root-user}" | base64 -d && echo
kubectl get secret minio -n minio -o jsonpath="{.data.root-password}" | base64 -d && echo
```

####

```sh
kubectl get secrets -n minio
```

```sh
kubectl get secret minio -n minio -o jsonpath="{.data.rootUser}" | base64 -d && echo
kubectl get secret minio -n minio -o jsonpath="{.data.rootPassword}" | base64 -d && echo
```

delete

```sh
helm uninstall minio -n minio || true
kubectl delete ns minio --wait=true || true
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete ingress minio-ingress
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete certificate minio-tls
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete secret minio-tls
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete service minio
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete deployment minio
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete pvc minio-data
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete sa minio
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio delete secrets minio-root
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n minio get all
kubectl -n minio get ingress,certificate,secret,svc,deploy,pvc
```

d2t
```sh
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app delete deployment doc2text
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app delete rs -l app=doc2text
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app delete pods -l app=doc2text --now
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app get all -l app=doc2text

KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app get deployment doc2text
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app get rs -l app=doc2text
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n app get pods -l app=doc2text -o wide
```