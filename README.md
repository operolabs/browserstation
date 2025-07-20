<div align="center">
  <img 
  alt="Browserstation Logo" 
  src="https://i.ibb.co/SXqtZ8dj/browserstation.png" 
  style="margin: 20px auto;"
>
  <p>Open-source, infra-agnostic hosting framework for browser agents. Debug locally. Scale to production.</p>
  <p>
    <a href="https://github.com/operolabs/browserstation/stargazers">
      <img src="https://img.shields.io/github/stars/operolabs/browserstation?style=social?cacheSeconds=1" alt="GitHub stars"/>
    </a>
    <a href="https://x.com/operolabs" alt="Twitter account">
        <img src="https://img.shields.io/twitter/follow/OperoLabs?style=social?cacheSeconds=1" /></a>
    <a href="https://github.com/operolabs/browserstation/blob/main/LICENSE">
      <img src="https://img.shields.io/github/license/operolabs/browserstation?cacheSeconds=1" alt="License"/>
    </a>
  </p>
</div>

**Browserstation** is an open-source alternative to Browserbase. Give your agents and scrapers full browser capabilities, with the ability to debug locally and scale to production without being locked into proprietary infrastructure.

- **Infra Agnostic**: Deploy anywhere (AWS, GCP, Azure, on-prem, or local Docker/Kubernetes).
- **Cost Efficient**: Up to 85% lower cost on EKS at scale vs. managed solutions like Browserbase.
- **Hackable** – A barebones core that’s easy to customize.

## Quick Start

<video src="./assets/browserstation.mp4" autoplay loop muted controls width="100%"></video>

### 1. Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.23
- [Helm](https://helm.sh/docs/intro/install/) >= 3.4
- [Kind](https://kind.sigs.k8s.io/) for local clusters
- [Docker](https://docs.docker.com/get-docker/)

### 2. Deploy

> Note: You must set an API key for authentication and security.

On macOS (Apple Silicon):

```bash
chmod +x scripts/quickstart.sh
./scripts/quickstart.sh --arm --api-key="your-secret-key"

```

_For macOS (Intel), Windows (using WSL), and Linux: use `./scripts/quickstart.sh --x86 ..."` instead._


### 3. Test

Set your API key and run the test:

```bash
export BROWSERSTATION_API_KEY="your-secret-key"
uv run tests/test_websocket.py

```

Monitor the cluster:

```bash
kubectl get pods -n ray-system
curl http://localhost:8050

```

Clean up the deployment:

```bash
./scripts/teardown.sh

```

### 4. Integrate

See [examples](https://github.com/operolabs/browserstation/tree/main/examples) to connect Browserstation to **Browser-use**, **Langchain**, or **CrewAI**.

## API Endpoints

| Endpoint                          | Description                                      |
|------------------------------------|--------------------------------------------------|
| `GET /`                           | Health check                                     |
| `POST /browsers`                  | Launch a new sandboxed Chrome instance           |
| `GET /browsers`                   | List all running browsers & CPU usage            |
| `GET /browsers/{id}`              | Get info and WebSocket URL for a browser         |
| `DELETE /browsers/{id}`           | Shut down a browser instance                     |
| `WS /ws/browsers/{id}/{path}`     | Chrome DevTools Protocol WebSocket stream        |

CDP access allows robust control for automation, proxy support, and live screen inspection.

## Architecture

### Sidecar Pattern & WebSocket Proxy

The system is built on **RayKube**, which manages a Kubernetes cluster with a head node and multiple worker nodes. The architecture is designed to be simple, configurable, and easy to extend.

<p align="center">
  <img src="./assets/architecture.png" alt="BrowserStation Architecture" width="55%">
</p>

#### 1. Sidecar Pattern

Each worker pod runs two containers:

- **Ray Worker (main container):** Hosts the `BrowserActor`, which manages browser lifecycle, handles API requests, allocates resources, and communicates with Chrome via `localhost:9222`.
- **Chrome (sidecar container):** Runs headless Chrome with remote debugging enabled, exposing the Chrome DevTools Protocol (CDP) on port 9222. Each pod provides an isolated browser instance.

#### 2. Unified CDP WebSocket Proxy

Clients connect to `/ws/browsers/{id}/devtools/browser` on the head node. FastAPI validates the browser ID and ensures the corresponding Chrome instance is ready. It then proxies a bidirectional WebSocket to the Chrome container in the appropriate worker pod.

This setup enables full access to CDP, allowing automation tools to control and inspect the browser seamlessly.



## Production Deployments

A full production deployment guide is available [here](./terraform/aws/README.md). Support for Azure AKS and GCP GKE is coming soon.

## Roadmap

- [ ] Browser persistence and session state
- [ ] Frontend dashboard for session analytics
- [ ] Azure AKS and GCP GKE support
- [ ] [Zendriver stealth integration](https://github.com/stephanlensky/zendriver)
- [ ] File download/upload management
- [ ] Resource management & optimization

## Contributing

- Fork the repository and create a new branch for your changes.
- Make your edits (please follow the existing code style and add/update tests if needed).
- Commit and push your branch.
- Open a pull request with a clear description of your changes.

Before starting major work, please [check open issues](https://github.com/operolabs/browserstation/issues), or [open a new issue](https://github.com/operolabs/browserstation/issues/new) to discuss ideas or bugs.

Thank you for helping improve Browserstation!

## License
[MIT](./LICENSE)

<br>
<div align="center">
  <sub>
    Made with ❤️ by <a href="https://www.operolabs.com/">Opero Labs</a>
  </sub>
</div>
