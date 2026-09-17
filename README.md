# Airflow on Aiven Runtime

This repository contains a Compose file and Docker (Container) file for
deploying the Standalone version of
[Apache Airflow](https://airflow.apache.org/) on [Aiven Runtime](https://aiven.io/runtime).

## Overview

Apache Airflow is a platform to programmatically author, schedule, and monitor
workflows. This project provides a containerized setup that:

- Extends the official Apache Airflow Docker image
- Runs webserver, scheduler, and triggerer in a single container (`airflow standalone`)
- Uses LocalExecutor (no Redis/Celery required)
- Sets up a user and password using the Simple Auth Manager
- Automatically runs database migrations on startup
- Configures the application for Aiven Runtime deployment

## Quickstart

- Make your own copy of this repository
- Add a Python DAG script to the `dags/` directory.
  The [Astronaut ETL example DAG](https://github.com/astronomer/astro-example-dags/blob/main/dags/example_astronauts.py) DAG from https://github.com/astronomer/astro-example-dags is straightforwad and engaging, and has no extra external dependencies.
- Commit the DAG file, and remember to push upstream to your GitHub repository.
- Follow the documentation to
  [Deploy to Aiven Runtime](https://aiven.io/docs/products/runtime/deploy-apps).
  In particular:

   - Select your GitHub account. Connect it to your Aiven organization if 
     this is the first time deploying from it.
   - Select your repository and branch.
   - Select the `compose.aiven.yaml` file and scan it
   - On the card for the application
   
      - Set the `USERNAME` and `PASSWORD`
      - Choose an appropriate plan - at least 2 vCPU and 4 GB RAM

- When the application is running, click on the **Application URL** to open 
  the Airflow dashboard and login using the username and password you specified.

## Resource Requirements

Airflow standalone runs webserver, scheduler, triggerer, DAG processor, and API server in one container. Recommended compute:

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM**  | 2 GB    | **4–8 GB**  |
| **CPU**  | 1 vCPU  | **2 vCPUs** |

Startup can take **5–7 minutes** with limited resources. If the app is slow to become ready or returns Bad Gateway, increase RAM to at least 4 GB. The [official Docker guide](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose.html) recommends 4 GB minimum, 8 GB for smoother operation.

## Deploying with the Compose file

If you use the Aiven [web console](https://console.aiven.io/) to deploy using the Compose file,
`compose.aiven.yaml`, then much of the setup is handled automatically.

By default, a new PostgreSQL database will be created. You can configure it 
to set its plan, region and so on.

Alternatively, if you already have an existing database, you can select it.

## Deploying with the Container file

If you deploy using the Container file, `Dockerfile`, then you need to 
specify the following environment variables:

- `AIRFLOW__DATABASE__SQL_ALCHEMY_CONN` or `DATABASE_URL` - The PostgreSQL 
  connection string for Airflow metadata. This should have the format
  ```
  postgresql+psycopg2://username:password@hostname:port/database
  ```

  If you're using an Aiven for PostgreSQL service, then this is the 
  **Service URI** from the service overview page.

  Ensure the database user has sufficient permissions to create tables and run
  migrations.

  > **Note:** When you connect a PostgreSQL service in Aiven Runtime's "Connect
  services" step, Aiven automatically injects `DATABASE_URL`. The entrypoint
  detects this and configures Airflow accordingly.

- `USERNAME` and `PASSWORD` - These specify the user to set up.

You can also specify the following optional values:

- `AIRFLOW_UID` - The User ID for file permissions (default: 50000)
- `PORT` - The port the webserver will listen on.

> For more on what environment variables are used, look in
> [entrypoint.sh](./entrypoint.sh).
> Note that the Aiven console does not let you specify environment 
> variable keys that start with `_`. The entrypoint script aliases
> values like `_AIRFLOW_DB_MIGRATE` as `AIRFLOW_DB_MIGRATE`.

## User names and passwords

The Standalone configuration of Airflow uses the
[Simple Auth Manager](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/auth-manager/simple/index.html).
Unlike the
[FAB](https://airflow.apache.org/docs/apache-airflow-providers-fab/stable/index.html)
that was provided before Airflow 3, the Simple Auth Manager
does not support setting username and password from environment
variables. It also doesn't store user information in the database. Instead it
reads from a JSON file.

> **Note:** The Airflow documentation emphasises that a production
> deployment of Airflow should be using a more sophisticated auth manager than
> either FAB _or_ the Simple Auth Manager.

If you specify both the `USERNAME` and `PASSWORD` environment values, then
the appropriate file will be created. The runtime logs will reflect this:

```
Password for the admin user has been previously generated in /opt/airflow/passwords.json. Not echoing it here.
```

If you don't specify both `USERNAME` and `PASSWORD`, then an admin user
with a random password will be generated. This is also recorded in the runtime
log, but in this case the username and password are actually logged. For
instance

```
Simple auth manager | Password for user 'admin': 5vdQkTqhCsY7e3yY
```

## Project Structure

```
.
├── compose.aiven.yaml  # A Compose file for deploying on Aiven Runtime
├── Dockerfile          # Extends official Airflow image
├── entrypoint.sh       # Startup script: validates env, runs migrations, starts Airflow
├── dags/               # Add your DAG files here (embedded in image)
├── .gitattributes      # Git configuration for line endings
└── README.md           # This file
```

## How It Works

1. **Build**: Extends `apache/airflow:<version>` (check the `Dockerfile` 
   for the current `<version>`) with:
   - Custom entrypoint for validation and migrations
   - DAGs from the `dags/` directory

2. **Runtime**: The entrypoint script:
   - Sets up LocalExecutor configuration (no Redis or Valkey needed)
   - Validates that `AIRFLOW__DATABASE__SQL_ALCHEMY_CONN` is set
   - Creates the username/password file if necessary
   - Runs database migrations automatically
   - Starts Airflow in standalone mode (webserver + scheduler + triggerer in one process)

## Adding DAGs

Add your DAG files to the `dags/` directory in this repository. They will be copied into the image at build time. After pushing changes, trigger a new deployment in Aiven to pick up the new DAGs.

If you just want to get started, the [Astronaut ETL example DAG](https://github.com/astronomer/astro-example-dags/blob/main/dags/example_astronauts.py) DAG from https://github.com/astronomer/astro-example-dags is straightforwad and engaging, and has no extra external dependencies.

## Customization

### Using a Different Airflow Version

To use a different Airflow image version, set the `AIRFLOW_IMAGE` argument 
in the `Dockerfile`:

```dockerfile
ARG AIRFLOW_IMAGE=apache/airflow:3.3.2
```

### Adding Providers

To add Airflow providers (for PostgreSQL, HTTP, and so on), create a 
`requirements.txt` file:

```
apache-airflow-providers-postgres
apache-airflow-providers-http
```

Then add to the `Dockerfile` before the `CMD`:

```dockerfile
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt
```

## Limitations

- **Stateless**: Logs are ephemeral. For persistent logs, configure external logging (e.g. Aiven for OpenSearch).
- **LocalExecutor only**: No Celery worker support. For parallel task execution, use a Kubernetes deployment instead.
- **Single instance**: Suitable for development and moderate workloads. For high availability, use the [Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/stable/index.html) on Kubernetes.

## Troubleshooting

### Bad Gateway (502) When Accessing the UI

1. **Wait for startup** – Airflow standalone can take 3–5 minutes to fully start. The container may show "Running" before the webserver is ready. Wait a few minutes and try again.

2. **Check application logs** – In Aiven, open the application logs and look for:
   - `Running on http://0.0.0.0:8080` (webserver started successfully)
   - Database connection errors
   - Python tracebacks or migration failures

3. **Try the root URL** – Use `https://<your-app-url>/` (without `/login`). Airflow may redirect you to the login page.

4. **Verify port** – Ensure the internal port in Aiven matches 8080 (Airflow's default). If Aiven injects a `PORT` env var, the entrypoint uses it automatically.

### Database Connection Issues

- Verify your PostgreSQL connection string is correct
- Ensure the database is accessible from App Runtime (check VPC/network configuration)
- Check that the database user has necessary permissions (CREATE, ALTER, etc.)

### Migration Failures

- Check the application logs for specific migration errors
- Ensure the database is empty or compatible with Airflow's schema
- Verify the connection string uses `postgresql+psycopg2://` (not `postgresql://`)

### Port Configuration

- Ensure port 8080 (or `PORT` if set) is opened in your App Runtime configuration
- If Aiven injects a `PORT` variable, the entrypoint automatically configures Airflow to use it

## Security Considerations

- Use a strong password for `PASSWORD`
- For production, strongly consider configuring
  [Airflow authentication](https://airflow.apache.org/docs/apache-airflow/stable/security/webserver.html) (OAuth, LDAP, etc.)
- Restrict network access to the application as appropriate
- Do not commit secrets to the repository; use Aiven's environment variable configuration

## Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Airflow Docker Image](https://airflow.apache.org/docs/docker-stack/)
- [Aiven Runtime Documentation](https://aiven.io/docs/products/runtime)

## License

This deployment configuration is provided as-is under an MIT license.
Apache Airflow is licensed under the Apache License 2.0.
