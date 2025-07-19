apiVersion: ray.io/v1alpha1
kind: RayService
metadata:
  name: browser-cluster
  namespace: ray-system
spec:
  rayClusterConfig:
    rayVersion: "${ray_version}"
    headGroupSpec:
      rayStartParams:
        dashboard-host: "0.0.0.0"
        num-cpus: "0"
      template:
        spec:
          containers:
          - name: ray-head
            image: "${image_repo}:latest"
            imagePullPolicy: IfNotPresent
            ports:
            - containerPort: 8050
              name: http
            command:
              ["/bin/bash","-c",
               "ray start --head --port=6379 \
                --dashboard-host=0.0.0.0 --metrics-export-port=8080 \
                --num-cpus=0 --block & \
                sleep 5 && uvicorn app.main:app --host 0.0.0.0 --port 8050"]
    workerGroupSpecs:
    - groupName: browser-workers
      minReplicas: ${min_replicas}
      maxReplicas: ${max_replicas}
      rayStartParams: {}
      template:
        spec:
          containers:
          - name: ray-worker
            image: "${image_repo}:latest"
            imagePullPolicy: IfNotPresent
            resources:
              requests: { cpu: "100m", memory: "512Mi" }
              limits:   { cpu: "200m", memory: "1Gi" }
          - name: chrome
            image: "zenika/alpine-chrome:100"
            args: ["--no-sandbox","--remote-debugging-address=0.0.0.0","--remote-debugging-port=9222"]
            ports:
            - containerPort: 9222
              name: devtools
            resources:
              requests: { cpu: "900m", memory: "768Mi" }
              limits:   { cpu: "900m", memory: "1Gi" }
---
apiVersion: v1
kind: Service
metadata:
  name: browser-cluster-public
  namespace: ray-system
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: kuberay
    ray.io/node-type: head
  ports:
  - name: serve
    port: 8050
    targetPort: 8050
