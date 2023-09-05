How to Use this Repository
==========================

Files in rpm/deb package epages-nodejs come from three GIT repositories:

<dl>
  <dt>git@github.com:ePages-de/node-binaries/data/ (this repository)</dt>
  <dd>contains nodejs files and required modules</dd>
  <dt>git@github.com:ePages-de/node-epages6</dt>
  <dd>contains ePages nodejs code</dd>
  <dt>git@github.com:ePages-de/epages6-packages/pkg/epages-nodejs/data/</dt>
  <dd>contains additionally shell scripts</dd>
</dl>

Files in this repository (node-binaries) can be updated by executing:

### Install Build Tools on CentOS-Only VM

```
sudo yum update
cd
yum -y install git
rm -rf ~/epages6-packages
git clone git@github.com:ePages-de/epages6-packages

~/epages6-packages/scripts/PrepareBuildHost.sh -y
```

### Install This Repository (node-binaries)

```
cd
rm -rf ~/node-binaries
git clone git@github.com:ePages-de/node-binaries
```

### Update ~/node-binaries/control/build.conf

Check what modules shall be added to nodejs:

```ini
[npm-modules]
jquery=1
jsdom=1
karma=1
karma-qunit=1
karma-requirejs=1
node-epages6=1
qunitjs=1
requirejs=1
```

and what nodejs version do you want to install:

```ini
[nodejs]
# version is either latest or from package found in download_dir:
# node-VERSION-linux-x64.tar.gz (e.g. v0.10.48)
download_dir=http://nodejs.org/dist/v0.10.40/
version=v0.10.40
#download_dir=http://nodejs.org/dist/latest-v0.10.x
#version=latest
```
**Note: If the version is latest than you can find the actual binary version in `data/srv/epages/eproot/Perl/bin/nodejs.d/CHANGELOG.md`**

**Note: that you only can use nodejs binaries up to glibc 2.9 because we
still support CentOS 6.**

### Build new NodeJS Binaries

Choose a directory where to put the new nodejs binaries, say
`/tmp/node/`. Then execute:

```
cd ~/node-binaries/control
./BuildNodeJS.sh -c build.conf -d /tmp/node
```

After successful execution update `~/node-binaries/data` by
`/tmp/node/data` and commit the changes.
