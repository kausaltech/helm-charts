package:
	helm package django-helm/ nextjs-helm/ -d charts && \
	helm repo index . --url https://kausaltech.github.io/helm-charts
