# Use the official NGINX image as the base.
FROM nginx:stable-alpine

# Remove the default welcome page shipped with the base image.
RUN rm -rf /usr/share/nginx/html/*

# Copy our static website into the directory NGINX serves by default.
COPY www/ /usr/share/nginx/html/

# Document that the container listens on port 80 (HTTPS is terminated at ingress).
EXPOSE 80

# Default command starts NGINX in the foreground.
CMD ["nginx", "-g", "daemon off;"]
