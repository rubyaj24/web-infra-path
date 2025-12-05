#!/bin/bash

# Logo Download Script for SaaS Infrastructure Learning Path
# This script downloads logos for all tools mentioned in the repository

LOGOS_DIR="./images/logos"
TEMP_DIR="/tmp/saas-logos"

# Create directories
mkdir -p "$LOGOS_DIR"
mkdir -p "$TEMP_DIR"

echo "🎨 Starting logo download process..."
echo "📁 Logos will be saved to: $LOGOS_DIR"

# Function to download and process logo
download_logo() {
    local name="$1"
    local url="$2"
    local filename="$3"
    
    echo "📥 Downloading $name..."
    if curl -s -L "$url" -o "$TEMP_DIR/$filename"; then
        # Convert to PNG if needed and resize to 32x32
        if command -v convert &> /dev/null; then
            convert "$TEMP_DIR/$filename" -resize 32x32 -background transparent "$LOGOS_DIR/$filename"
            echo "✅ Processed $name -> $filename"
        else
            cp "$TEMP_DIR/$filename" "$LOGOS_DIR/$filename"
            echo "✅ Downloaded $name -> $filename (ImageMagick not available for resizing)"
        fi
    else
        echo "❌ Failed to download $name"
    fi
}

# Development Tools
download_logo "React" "https://raw.githubusercontent.com/devicons/devicon/master/icons/react/react-original.svg" "react.png"
download_logo "Vue.js" "https://raw.githubusercontent.com/devicons/devicon/master/icons/vuejs/vuejs-original.svg" "vue.png"
download_logo "Angular" "https://raw.githubusercontent.com/devicons/devicon/master/icons/angularjs/angularjs-original.svg" "angular.png"
download_logo "Node.js" "https://raw.githubusercontent.com/devicons/devicon/master/icons/nodejs/nodejs-original.svg" "nodejs.png"
download_logo "Express.js" "https://raw.githubusercontent.com/devicons/devicon/master/icons/express/express-original.svg" "express.png"
download_logo "Django" "https://raw.githubusercontent.com/devicons/devicon/master/icons/django/django-plain.svg" "django.png"
download_logo "FastAPI" "https://raw.githubusercontent.com/devicons/devicon/master/icons/fastapi/fastapi-original.svg" "fastapi.png"
download_logo "Flask" "https://raw.githubusercontent.com/devicons/devicon/master/icons/flask/flask-original.svg" "flask.png"

# Databases
download_logo "PostgreSQL" "https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" "postgresql.png"
download_logo "MySQL" "https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" "mysql.png"
download_logo "MongoDB" "https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" "mongodb.png"
download_logo "Redis" "https://raw.githubusercontent.com/devicons/devicon/master/icons/redis/redis-original.svg" "redis.png"

# DevOps & Cloud
download_logo "Docker" "https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" "docker.png"
download_logo "Kubernetes" "https://raw.githubusercontent.com/devicons/devicon/master/icons/kubernetes/kubernetes-plain.svg" "kubernetes.png"
download_logo "AWS" "https://raw.githubusercontent.com/devicons/devicon/master/icons/amazonwebservices/amazonwebservices-original-wordmark.svg" "aws-ec2.png"
download_logo "Azure" "https://raw.githubusercontent.com/devicons/devicon/master/icons/azure/azure-original.svg" "azure-app-service.png"
download_logo "Google Cloud" "https://raw.githubusercontent.com/devicons/devicon/master/icons/googlecloud/googlecloud-original.svg" "gcp-compute.png"
download_logo "Terraform" "https://raw.githubusercontent.com/devicons/devicon/master/icons/terraform/terraform-original.svg" "terraform.png"

# Frontend Tools
download_logo "Tailwind CSS" "https://raw.githubusercontent.com/devicons/devicon/master/icons/tailwindcss/tailwindcss-plain.svg" "tailwind.png"
download_logo "Bootstrap" "https://raw.githubusercontent.com/devicons/devicon/master/icons/bootstrap/bootstrap-original.svg" "bootstrap.png"
download_logo "Sass" "https://raw.githubusercontent.com/devicons/devicon/master/icons/sass/sass-original.svg" "sass.png"
download_logo "Redux" "https://raw.githubusercontent.com/devicons/devicon/master/icons/redux/redux-original.svg" "redux.png"

# CI/CD Tools
download_logo "GitHub" "https://raw.githubusercontent.com/devicons/devicon/master/icons/github/github-original.svg" "github-actions.png"
download_logo "GitLab" "https://raw.githubusercontent.com/devicons/devicon/master/icons/gitlab/gitlab-original.svg" "gitlab.png"
download_logo "Jenkins" "https://raw.githubusercontent.com/devicons/devicon/master/icons/jenkins/jenkins-original.svg" "jenkins.png"

# Monitoring
download_logo "Prometheus" "https://raw.githubusercontent.com/devicons/devicon/master/icons/prometheus/prometheus-original.svg" "prometheus.png"
download_logo "Grafana" "https://raw.githubusercontent.com/devicons/devicon/master/icons/grafana/grafana-original.svg" "grafana.png"

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Logo download completed!"
echo "📊 Total logos downloaded: $(ls -1 "$LOGOS_DIR"/*.png 2>/dev/null | wc -l)"
echo ""
echo "📝 Note: Some logos may need manual optimization or replacement with official brand assets."
echo "🔗 Check the logos/README.md file for official logo sources and brand guidelines."
echo ""
echo "💡 To optimize all logos to the same size, run:"
echo "   find $LOGOS_DIR -name '*.png' -exec convert {} -resize 32x32 {} \\;"