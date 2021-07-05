# openfaas-sgemm

This repo hosts an example unikernel invocation for OpenFaaS.

### Input

No input yet

### Output

The output is simply the stdout of the unikernel execution.

### Build as a standalone app

To build we use the dockerfile. 

```
docker build -t user/unikernel-example-faas:latest -f Dockerfile .
```
then push to the dockerhub:

```
docker push user/unikernel-example-faas:latest
```

and use the stack-unik.yml to deploy to your openfaas installation:

```
faas-cli deploy -f stack-unik.yml
```

Make sure to use your own gateway param, as well as your own openfaas profile
annotation.
