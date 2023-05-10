<div align="center">
  <img src="https://blog.zachinachshon.com/assets/images/container-registry/docker-registry/docker-registry-blog-220x230.png" width="150" align="center">
</div>

# วิธีติดตั้ง Docker Private Registry

สิ่งที่ควรมีก่อนทำ Step ข้างล่าง
- [Docker](https://docs.docker.com/engine/install/centos/)
- [Docker Compose](https://docs.docker.com/compose/install/other/)
- [Apache2-Utils](https://open4tech.com/install-htpasswd-on-centos/)
- [Mod_SSL](https://www.configserverfirewall.com/hosting/generate-self-signed-certificate-in-centos-7/)
---
> ### ขั้นตอนนี้ทำที่ฝั่ง Registry Server

### ตั้งค่า Hostname
<p style="color: red;"><u>ขั้นตอนนี้หากมี Domain name อยู่แล้วไม่จำเป็นต้องทำ</u></p>

```bash
$ echo "registry.softnix" > /etc/hostname
#Restart
$ init 6
```
### สร้าง Directory Bind volumes to container
```bash
$ mkdir -p /home/registry/{certs, data, auth}
```
### SSH Key generate
<p style="color: red;"><u>ขั้นตอนนี้หากมี Domain name อยู่แล้วไม่จำเป็นต้องทำ</u></p>

```bash
$ ssh-keygen
$ ssh-copy-id registry.softnix
#ถ้ามีเครื่อง Client ให้ทำเช่นเดียวกันทุกๆเครื่อง
$ ssh-copy-id client_host
```
### กำหนดค่า Docker daemon
```bash
$ vim /etc/docker/daemon.json
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
<p style="color: red;"><u>ขั้นตอนนี้หากมี Domain name อยู่แล้วไม่จำเป็นต้องทำ</u></p>

```bash
$ vim /etc/hosts
#Add <IP Address> <Hostname>
192.168.10.109 registry.softnix
192.168.10.23 another.client
```
### Generate SSL Key Certs
<p style="color: red;"><u>ขั้นตอนเป็นการทำ Self-certs ใช้เฉพาะภายใน Local Network หากมี Domain name อยู่แล้วไม่ต้องทำ</u></p>

```bash
$ openssl req -newkey \
rsa:4096 \
-nodes -sha256 -keyout /home/registry/certs/ca.key \
-x509 -days 365 -out /home/registry/certs/ca.crt \
-subj "/CN=registry.softnix" \
-addext "subjectAltName = DNS:registry.softnix"
```
### สร้าง cert.d ของ Docker
```bash
$ mkdir -p /etc/docker/certs.d/registry.softnix:5000
$ cp /home/registry/certs/ca.crt /etc/docker/certs.d/registry.softnix:5000/ca.crt
```
### สร้าง Authentication ผ่าน htpasswd
```bash
#ครั้งแรกให้รันคำสั่งนี้ก่อนเพื่อสร้างไฟล์ขึ้นมาใหม่
$ htpasswd -Bc /home/registry/auth/htpasswd username
#ถ้าอยากจะเพิ่ม User เพิ่มเติมให้รันคำสั่งนี้
$ htpasswd -B /home/registry/auth/htpasswd username
```
### Deploy Docker Registry By Docker Run
```bash
$ docker run --name registry \
-p 5000:5000 \
--restart=always \
-v /home/registry/certs:/etc/certs \
-v /home/registry/auth:/etc/auth \
-v /home/registry/data:/var/lib/registry \
-e "REGISTRY_AUTH=htpasswd" \
-e REGISTRY_STORAGE_DELETE_ENABLED=true
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
      REGISTRY_STORAGE_DELETE_ENABLED: true
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /etc/auth/htpasswd
      REGISTRY_HTTP_TLS_CERTIFICATE: /etc/certs/ca.crt
      REGISTRY_HTTP_TLS_KEY: /etc/certs/ca.key
```
---
> ### ฝั่ง Cilent

### แลก SSH Key
<p style="color: red;"><u>ขั้นตอนนี้หากมี Domain name อยู่แล้วไม่จำเป็นต้องทำ</u></p>

```bash
$ $ssh-keygen
#แลก Key ไปที่ฝั่ง Server
$ $ssh-copy-id registry.softnix
#ฝั่ง Server แลกมา
$ $ssh-copy-id client_host
```
### Copy certs file
<p style="color: red;"><u>ขั้นตอนนี้หากมี Domain name อยู่แล้วไม่จำเป็นต้องทำ</u></p>

```bash
$ mkdir -p /etc/docker/certs.d/registry.softnix:5000
$ scp registry.soft$ $nix:/etc/docker/certs.d/registry.softnix:5000/ca.crt \
/etc/docker/certs.d/registry.softnix:5000
```
### ทดสอบ Login ว่าสามารถใช้งานได้หรือไม่
```bash
$ docker login registry.softnix:5000
#Login
Username: ที่ได้สร้างไว้ใน htpasswd
Password: ที่ได้สร้างไว้ใน htpasswd
```
### ทดสอบ Push ขึ้ไปยัง Registry
```bash
#ลอง pull มาจาก docker.io
$ docker pull alpine:latest
$ docker images
$ docker tag image_id registry.softnix:5000/alpine:latest
#Pattern
#<registry_server>:<port>/<images_name>:<tag>
$ docker push registry.softnix:5000/alpine:latest
```
### ทดสอบ Pull มาใช้งาน
```bash
$ docker pull registry.softnix:5000/alpine:latest
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
### วิธีการติดตั้ง Script Remove Image in Registry

```sh
$ cd /usr/local/bin
$ curl -O https://raw.githubusercontent.com/ezynook/docker-private-registry/main/remove_image.sh
$ mv remove_image.sh remove_image
$ chmod +x remove_image
```

### วิธีการใช้งาน Script Remove Image in Registry

```bash
$ remove_image
```

หลังจากรัน Script จะมีช่องให้กรอกดังนี้
* 1. Image Name
* 2. Tag Name

ถ้าไม่มีการกรอก Tag Name จะเป็นการลบ Image นั้นๆ ทุก Tag
หากระบุทั้ง Image name และ Tag name จะเป็นการลบ Image เฉพาะ Tags ที่ระบุไว้เท่านั้น

---
> Pasit Yodsoi @Data Engineer