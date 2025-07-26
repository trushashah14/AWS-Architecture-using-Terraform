#!/bin/bash
apt-get update -y
apt-get install -y python3

mkdir -p /var/www/html
echo "<h1>Hello from $(hostname -I)</h1>" > /var/www/html/index.html

cd /var/www/html
nohup python3 -m http.server 80 &