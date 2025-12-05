# Logo Download Script for SaaS Infrastructure Learning Path
# PowerShell version for Windows users

$LogosDir = ".\images\logos"
$TempDir = "$env:TEMP\saas-logos"

# Create directories
New-Item -ItemType Directory -Path $LogosDir -Force | Out-Null
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

Write-Host "🎨 Starting logo download process..." -ForegroundColor Green
Write-Host "📁 Logos will be saved to: $LogosDir" -ForegroundColor Cyan

# Function to download logo
function Download-Logo {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Filename
    )
    
    Write-Host "📥 Downloading $Name..." -ForegroundColor Yellow
    try {
        $TempFile = Join-Path $TempDir $Filename
        $FinalFile = Join-Path $LogosDir $Filename
        
        Invoke-WebRequest -Uri $Url -OutFile $TempFile -ErrorAction Stop
        Copy-Item $TempFile $FinalFile -Force
        Write-Host "✅ Downloaded $Name -> $Filename" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to download $Name" -ForegroundColor Red
    }
}

# Development Tools
Download-Logo "React" "https://raw.githubusercontent.com/devicons/devicon/master/icons/react/react-original.svg" "react.svg"
Download-Logo "Vue.js" "https://raw.githubusercontent.com/devicons/devicon/master/icons/vuejs/vuejs-original.svg" "vue.svg"
Download-Logo "Angular" "https://raw.githubusercontent.com/devicons/devicon/master/icons/angularjs/angularjs-original.svg" "angular.svg"
Download-Logo "Node.js" "https://raw.githubusercontent.com/devicons/devicon/master/icons/nodejs/nodejs-original.svg" "nodejs.svg"
Download-Logo "Express.js" "https://raw.githubusercontent.com/devicons/devicon/master/icons/express/express-original.svg" "express.svg"
Download-Logo "Django" "https://raw.githubusercontent.com/devicons/devicon/master/icons/django/django-plain.svg" "django.svg"
Download-Logo "FastAPI" "https://raw.githubusercontent.com/devicons/devicon/master/icons/fastapi/fastapi-original.svg" "fastapi.svg"
Download-Logo "Flask" "https://raw.githubusercontent.com/devicons/devicon/master/icons/flask/flask-original.svg" "flask.svg"

# Databases
Download-Logo "PostgreSQL" "https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" "postgresql.svg"
Download-Logo "MySQL" "https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" "mysql.svg"
Download-Logo "MongoDB" "https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" "mongodb.svg"
Download-Logo "Redis" "https://raw.githubusercontent.com/devicons/devicon/master/icons/redis/redis-original.svg" "redis.svg"

# DevOps & Cloud
Download-Logo "Docker" "https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" "docker.svg"
Download-Logo "Kubernetes" "https://raw.githubusercontent.com/devicons/devicon/master/icons/kubernetes/kubernetes-plain.svg" "kubernetes.svg"
Download-Logo "AWS" "https://raw.githubusercontent.com/devicons/devicon/master/icons/amazonwebservices/amazonwebservices-original-wordmark.svg" "aws-ec2.svg"
Download-Logo "Azure" "https://raw.githubusercontent.com/devicons/devicon/master/icons/azure/azure-original.svg" "azure-app-service.svg"
Download-Logo "Google Cloud" "https://raw.githubusercontent.com/devicons/devicon/master/icons/googlecloud/googlecloud-original.svg" "gcp-compute.svg"
Download-Logo "Terraform" "https://raw.githubusercontent.com/devicons/devicon/master/icons/terraform/terraform-original.svg" "terraform.svg"

# Frontend Tools
Download-Logo "Tailwind CSS" "https://raw.githubusercontent.com/devicons/devicon/master/icons/tailwindcss/tailwindcss-plain.svg" "tailwind.svg"
Download-Logo "Bootstrap" "https://raw.githubusercontent.com/devicons/devicon/master/icons/bootstrap/bootstrap-original.svg" "bootstrap.svg"
Download-Logo "Sass" "https://raw.githubusercontent.com/devicons/devicon/master/icons/sass/sass-original.svg" "sass.svg"
Download-Logo "Redux" "https://raw.githubusercontent.com/devicons/devicon/master/icons/redux/redux-original.svg" "redux.svg"

# CI/CD Tools
Download-Logo "GitHub" "https://raw.githubusercontent.com/devicons/devicon/master/icons/github/github-original.svg" "github-actions.svg"
Download-Logo "GitLab" "https://raw.githubusercontent.com/devicons/devicon/master/icons/gitlab/gitlab-original.svg" "gitlab.svg"
Download-Logo "Jenkins" "https://raw.githubusercontent.com/devicons/devicon/master/icons/jenkins/jenkins-original.svg" "jenkins.svg"

# Monitoring
Download-Logo "Prometheus" "https://raw.githubusercontent.com/devicons/devicon/master/icons/prometheus/prometheus-original.svg" "prometheus.svg"
Download-Logo "Grafana" "https://raw.githubusercontent.com/devicons/devicon/master/icons/grafana/grafana-original.svg" "grafana.svg"

# Clean up
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "🎉 Logo download completed!" -ForegroundColor Green
$LogoCount = (Get-ChildItem -Path $LogosDir -Filter "*.svg" | Measure-Object).Count
Write-Host "📊 Total logos downloaded: $LogoCount" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 Note: Downloaded as SVG files. Convert to PNG if needed." -ForegroundColor Yellow
Write-Host "🔗 Check the logos/README.md file for official logo sources and brand guidelines." -ForegroundColor Yellow
Write-Host ""
Write-Host "💡 To convert SVG to PNG (requires Inkscape or similar tool):" -ForegroundColor Cyan
Write-Host "   Get-ChildItem '$LogosDir\*.svg' | ForEach-Object { inkscape --export-png='$($_.DirectoryName)\$($_.BaseName).png' --export-width=32 --export-height=32 '$_' }" -ForegroundColor Gray