# nginx-deploy

A small, dependency-free bash toolkit for standing up **nginx as a reverse
proxy** in front of HTTP services on a Ubuntu/Debian server.

## Usage

```bash
git clone https://github.com/pterryt/nginx-deploy.git nginx-deploy
cd nginx-deploy
sudo ./install.sh
```

Then for each service:

```bash
cp env/services.d/service.env.dist env/services.d/myapp.env
$EDITOR services.d/myapp.env
sudo ./vhost.sh add env/services.d/myapp.env
```

### Example Env File

```ini
SERVICE_NAME=myapp
DOMAIN=myapp.example.com
UPSTREAM_PORT=3000
```
