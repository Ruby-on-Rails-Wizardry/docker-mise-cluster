# Local nginx front door for the multi-app cluster.
# Build once:  bin/compose build nginx
# Image is local-only (compose pull_policy: never).
#
# Config and static home page are baked in so bind-mount/permission issues
# on host mounts do not break the proxy.

FROM nginx:1.27-alpine

# Our server listens on 8080 (not the distro default 80).
COPY nginx.conf /etc/nginx/nginx.conf
COPY proxy.conf /etc/nginx/proxy.conf
COPY html/ /usr/share/nginx/html/

# nginx:alpine runs as root by default then drops workers; pid is under /tmp
# (see nginx.conf). No custom USER — keep stock entrypoint.
EXPOSE 8080

# Validate config at build time
RUN nginx -t

CMD ["nginx", "-g", "daemon off;"]
