# appstudio-e2e-demos

This repo contains a selection of App Studio Demos
The Demos consist of the Application and Components needed to bootstrap a demo as well as an "add-on" which adds content which is missing from app-studio generated gitops repos.

Demos can be added in the subdirectory called demos in a structure like the following.

```
/home/john/dev/appstudio-e2e-demos$ tree demos/graphtuitous/
demos/graphtuitous/
├── add-ons
│   ├── fibs-service
│   │   └── service.yaml
│   ├── frontend
│   │   └── service.yaml
│   ├── ha-proxy
│   │   ├── route.yaml
│   │   └── service.yaml
│   └── kustomization.yaml
├── components
│   ├── fib-go.yaml
│   ├── fib-node.yaml
│   ├── frontend.yaml
│   └── haproxy.yaml
└── devfiles
    ├── fib-go
    │   └── devfile.yaml
    ├── fib-node
    │   └── devfile.yaml
    ├── frontend
    │   └── devfile.yaml
    └── haproxy
        └── devfile.yaml
```    

`app` --- app studio application definition (OPTIONAL- if missing, one will be created from the directory name, easy peasy)

`devfiles` --- externally provided devfiles if original repo doesn't have one

`components` --- component definitions 

`add-ons` --- extra yaml needed for the app.



Run `./run.sh` to try it on a app studio cluster ...

<img width="953" alt="image" src="https://user-images.githubusercontent.com/7844190/172205712-983f2b33-ec77-453e-bf5b-b0c773f09469.png">


"s" will print status
<img width="1296" alt="image" src="https://user-images.githubusercontent.com/7844190/172205839-9b09be22-1755-4787-8053-b0393f35d782.png">

"t" will trigger all builds on all application components via triggers.

<img width="1295" alt="image" src="https://user-images.githubusercontent.com/7844190/172206008-7621046b-fc92-42d4-aab7-c4eba5d3ad1f.png">
