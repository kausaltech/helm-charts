DEST=../charts/mixins/templates

generate_manifests:
	rm -rf ./mixins/templates/*
	# Convert json to yaml
	jsonnet main.jsonnet -J vendor -m $(DEST) | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	# Remove all non yaml files
	find $(DEST) -type f ! -name "*.*" -exec rm {} +
	# Loop through each yaml file generated and escape it
	find $(DEST) -name '*.yaml' -exec python3 escape_yaml.py "{}" +
