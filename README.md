### Jsonnet Mixins

To ensure that the dashboards and alerts are created and work with K3s we use jsonnet to generate the manifests. The jsonnet files are stored in the `jsonnet` directory. The `jsonnet` directory.

To get started with jsonnet you'll need to install the following binaries using `go`:

```bash
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/brancz/gojsontoyaml@latest
```

Now you can `cd` into the jsonnet directory, and then you can install the dependencies using `jb`:

```bash
jb install
```

You can now generate the manifests using the following command:

```bash
make generate_manifests
```
