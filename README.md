<img src="https://blog.zachinachshon.com/assets/images/container-registry/docker-registry/docker-registry-blog-220x230.png" width="100" align="center">

# วิธีติดตั้ง Docker Registry Private

สิ่งที่ควรมีก่อนทำ Step ข้างล่าง
- Docker
- Docker Compose
- apache2-utils
- openssl
---
> ### ขั้นตอนนี้ทำที่ฝั่ง Registry Server

### ตั้งค่า Hostname

```bash
echo "registry.softnix" > /etc/hostname
#Restart
init 6
```
### สร้าง Directry ที่จำเป็น
```bash
mkdir -p /home/registry/{certs, data, auth}
```
### SSH Key generate
```bash
ssh-keygen
ssh-copy-id registry.softnix
#ถ้ามีเครื่อง Client ให้ทำเช่นเดียวกันทุกๆเครื่อง
ssh-copy-id client_host
```
### กำหนดค่า Docker daemon
```bash
vim /etc/docker/daemon.json
```
เพิ่มข้อความ Json ชุดนี้ลงไป
```bash
{
  "allow-nondistributable-artifacts": [
		"registry.softnix:5000"
	]
}
```
### ตั้งค่า hosts ใส่ข้อมูล Server, Client ทั้งหมดที่ต้องการใช้งาน Registry
```bash
vim /etc/hosts
#192.168.10.109 registry.softnix
#192.168.10.23 another.client
```
### Generate SSL Key Certs
```bash
openssl req -newkey \
rsa:4096 \
-nodes -sha256 -keyout /home/registry/certs/ca.key \
-x509 -days 365 -out /home/registry/certs/ca.crt \
-subj "/CN=registry.softnix" \
-addext "subjectAltName = DNS:registry.softnix"
```
### สร้าง cert.d ของ Docker
```bash
mkdir -p /etc/docker/certs.d/registry.softnix:5000
cp /home/registry/certs/ca.crt /etc/docker/certs.d/registry.softnix:5000/ca.crt
```
### สร้าง Authentication ผ่าน htpasswd
```bash
#ครั้งแรกให้รันคำสั่งนี้ก่อนเพื่อสร้างไฟล์ขึ้นมาใหม่
htpasswd -Bc /home/registry/auth/htpasswd username
#ถ้าอยากจะเพิ่ม User เพิ่มเติมให้รันคำสั่งนี้
htpasswd -B /home/registry/auth/htpasswd username
```
### Deploy Docker Registry By Docker Run
```bash
docker run --name registry \
-p 5000:5000 \
--restart=always \
-v /home/registry/certs:/etc/certs \
-v /home/registry/auth:/etc/auth \
-v /home/registry/data:/var/lib/registry \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/etc/auth/htpasswd \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/etc/certs/ca.crt \
-e REGISTRY_HTTP_TLS_KEY=/etc/certs/ca.key \
-d registry
```
### Deploy Docker Registry By Docker Compose
```yaml
version: '3.8'
services:
  registry:
    image: registry
    container_name: registry
    restart: always
    ports:
      - 5000:5000
    volumes:
      - /home/registry/certs:/etc/certs
      - /home/registry/auth:/etc/auth
      - /home/registry/data:/var/lib/registry
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /etc/auth/htpasswd
      REGISTRY_HTTP_TLS_CERTIFICATE: /etc/certs/ca.crt
      REGISTRY_HTTP_TLS_KEY: /etc/certs/ca.key
```
---
> ### ฝั่ง Cilent

### แลก SSH Key
```bash
ssh-keygen
#แลก Key ไปที่ฝั่ง Server
ssh-copy-id registry.softnix
#ฝั่ง Server แลกมา
ssh-copy-id client_host
```
### Copy certs file
```bash
mkdir -p /etc/docker/certs.d/registry.softnix:5000
scp registry.softnix:/etc/docker/certs.d/registry.softnix:5000/ca.crt /etc/docker/certs.d/registry.softnix:5000
```
### ทดสอบ Login ว่าสามารถใช้งานได้หรือไม่
```bash
docker login registry.softnix:5000
#Login
Username: ที่ได้สร้างไว้ใน htpasswd
Password: ที่ได้สร้างไว้ใน htpasswd
```
### ทดสอบ Push ขึ้ไปยัง Registry
```bash
#ลอง pull มาจาก docker.io
docker pull alpine:latest
docker images
docker tag image_id registry.softnix:5000/alpine:latest
#Pattern
#<registry_server>:<port>/<images_name>:<tag>
docker push registry.softnix:5000/alpine:latest
```
### ทดสอบ Pull มาใช้งาน
```bash
docker pull registry.softnix:5000/alpine:latest
```
### ไปที่ฝั่ง Server ดูว่ามี Images ที่เราได้ Push ไปมีอยู่หรือไม่
```javascript
https://registry.softnix:5000/v2/_catalog
```
### จะแสดงรายการ Image ที่มีอยู่ประมาณนี้
```javascript
{
	"repositories":[
		"alpine",
		"debian",
		"ubuntu"
	]
}
```
### วิธีการติดตั้ง Script ลบ Image
สร้างไฟล์ชื่อว่า remove_image.sh
```sh
vim ∼/.remove_image.sh
```
จากนั้น Copy Script ด้านล่างนี้ไปวาง
```bash
#!/bin/bash
#-----------------------------
#Author: Pasit Y. (2023-05-09)
#-----------------------------

echo "-> Enter the Image Name: "  
read val_image
echo "-> Enter the Tags Name: "  
read val_tag

if [ -z "$val_image" ]; then
    echo "Can't Running Without define Image name"
    exit 1
fi

if [ -n "$val_image" ]; then
    if [ -n "$val_tag" ]; then
        echo "Remove Image with Tags $val_image:$val_tag"
        rm -rf /home/registry/data/docker/registry/v2/repositories/$val_image/_manifests/tags/$val_tag >/dev/null 2>&1
    else
        echo "Remove Image all Tags $val_image"
        rm -rf /home/registry/data/docker/registry/v2/repositories/$val_image >/dev/null 2>&1
    fi
    docker exec -it registry bin/registry garbage-collect /etc/docker/registry/config.yml >/dev/null 2>&1
fi

```
### วิธีการใช้งาน Script
รัน Script

```bash
./remove_image.sh
```

หลังจากรัน Script จะมีช่องให้กรอกดังนี้
* 1. Image Name
* 2. Tag Name

ถ้าไม่มีการกรอก Tag Name จะเป็นการลบ Image นั้นๆ ทุก Tag
หากระบุทั้ง Image name และ Tag name จะเป็นการลบ Image เฉพาะ Tags ที่ระบุไว้เท่านั้น

### วิธีการเพิ่ม User Authentication
รันคำสั่งนี้ที่ Registry Server เท่านั้น
```bash

```
---
> Pasit Yodsoi @Data Engineer