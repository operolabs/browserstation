apiVersion: ray.io/v1alpha1
kind: RayService
metadata:
  name: browser-cluster
  namespace: ${namespace}
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
            image: ${image}
            imagePullPolicy: IfNotPresent
            ports:
            - containerPort: 8050
              name: http
            command: ["/bin/bash", "-c"]
            args:
            - |
              ray start --head --port=6379 \
              --dashboard-host=0.0.0.0 --metrics-export-port=8080 \
              --num-cpus=0 --block & \
              sleep 5 && uvicorn app.main:app --host 0.0.0.0 --port 8050%{ if api_key_secret != "" }
            envFrom:
            - secretRef:
                name: ${api_key_secret}%{ endif }
            resources:
              requests:
                cpu: "1"
                memory: "2Gi"
              limits:
                cpu: "2"
                memory: "4Gi"
    workerGroupSpecs:
    - groupName: browser-workers
      minReplicas: 0
      maxReplicas: ${max_workers}
      rayStartParams: {}
      template:
        spec:
          containers:
          - name: ray-worker
            image: ${image}
            imagePullPolicy: IfNotPresent
            resources:
              requests:
                cpu: "1"
                memory: "512Mi"
              limits:
                cpu: "2"
                memory: "1Gi"
          - name: chrome
            image: zenika/alpine-chrome:100
            args:
            - "--no-sandbox"
            - "--remote-debugging-address=0.0.0.0"
            - "--remote-debugging-port=9222"
            ports:
            - containerPort: 9222
              name: devtools
            resources:
              requests:
                cpu: "900m"
                memory: "768Mi"
              limits:
                cpu: "900m"
                memory: "1Gi"