## Database Management

### Scaling Storage

To increase your database storage size:

1. Stop the host:
    ```bash
    k8dev stop your.domain.dev
    ```
2. Edit your host's `values.yaml` and update the storage size:
    ```yaml
    mysql:
      storage:
        size: "20Gi"  # Increase from 5Gi to 20Gi
    ```
3. Start the host:
    ```bash
    k8dev start your.domain.dev
    ```

> **Important Notes:**
> - Storage can only be increased, not decreased
> - Data is preserved during scaling
> - The process may take a few minutes depending on the size
> - Ensure your system has enough available space

### Storage Location
Database files are persisted in:
```
./data/mysql/www-domain-dev/
```
This directory is preserved even after uninstalling the host or infrastructure.

### Backup Before Scaling
It's recommended to back up your database before scaling:

```bash
# Export database
kubectl exec -n k8dev-apps deploy/www-domain-dev-mysql -- \
  mysqldump -u root -p[root-password] [database-name] > backup.sql

# Import database (if needed)
kubectl exec -i -n k8dev-apps deploy/www-domain-dev-mysql -- \
  mysql -u root -p[root-password] [database-name] < backup.sql
```