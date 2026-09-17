# Apache Airflow on Aiven App Runtime
# Extends the official Airflow image for stateless deployment with PostgreSQL

ARG AIRFLOW_IMAGE=apache/airflow:3.1.8
FROM ${AIRFLOW_IMAGE}

# Airflow configuration for stateless App Runtime
ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor
ENV AIRFLOW__WEBSERVER__EXPOSE_CONFIG=false
ENV AIRFLOW__CORE__LOAD_EXAMPLES=false

# Airflow after 3.0.5 no longer includes the FAB auth manager. The Simple
# Auth Manager that _is_ included does not support setting username and
# password from environment variables.
# We are thus going to re-enable the FAB auth manager
ENV _PIP_ADDITIONAL_REQUIREMENTS=apache-airflow-fab-auth-manager
ENV AIRFLOW__CORE__AUTH_MANAGER=airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager

# Copy custom entrypoint (run as root - Airflow image uses non-root user)
USER root
COPY entrypoint.sh /entrypoint-custom.sh
RUN chmod +x /entrypoint-custom.sh
USER airflow

# Copy DAGs (add your DAGs to the dags/ directory)
COPY --chown=airflow:root dags/ /opt/airflow/dags/

# Use custom entrypoint that wraps Airflow's entrypoint
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/entrypoint-custom.sh"]
CMD ["standalone"]
