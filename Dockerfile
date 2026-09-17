# Apache Airflow on Aiven App Runtime
# Extends the official Airflow image for stateless deployment with PostgreSQL

ARG AIRFLOW_IMAGE=apache/airflow:3.1.8
FROM ${AIRFLOW_IMAGE}

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
