package:
	helm package django/ nextjs/ -d charts && \
	helm repo index . --url https://kausaltech.github.io/helm-charts
