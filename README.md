| CentOS        | [![Build Status (CentOS)](https://perfsonar-dev3.grnoc.iu.edu/jenkins/buildStatus/icon?job=perfsonar-lsregistrationdaemon-centos)](https://perfsonar-dev3.grnoc.iu.edu/jenkins/view/Debian/job/perfsonar-lsregistrationdaemon-centos/) | Debian      | [![Build Status (Debian)](https://perfsonar-dev3.grnoc.iu.edu/jenkins/buildStatus/icon?job=ls-registration-daemon-debian-source)](https://perfsonar-dev3.grnoc.iu.edu/jenkins/view/Debian/job/ls-registration-daemon-debian-source/) |
| -------------|-------------|-------------|-------------|

# perfSONAR Lookup Service Registration Daemon

The Lookup Service (LS) Registration daemon registers and maintains records with the lookup service. It includes features such as autodetecting hardware details of the host on which it is running and registering these as host and interface records in the Lookup Seervice. It also registers service records of the various perfSONAR components, in many cases detecting whether the service is up prior to registering and autodetcting service specific features where applicable. It opaquely handles most record management tasks, such as refreshing a record and avoiding duplicate registrations. It is designed to be extensible so that new registration types may be added with minimal effort.

## Getting the Code
You may checkout the code with the following command:

```
git clone --recursive https://github.com/perfsonar/ls-registration-daemon.git
```

Note the use of the `--recursive` option to ensure any submodule trees are included in the clone.

## Building and Installing

To install the code on your system run:

```bash
make install
```

## Packaging
You may create a source tarball of this code with the following:

```bash
make dist
```
## Running 

To start the service run:

```bash
/etc/init.d/perfsonar-lsregistrationdaemon start
```

To stop the service run:

```bash
/etc/init.d/perfsonar-lsregistrationdaemon stop
```

To restart the service run:

```bash
/etc/init.d/perfsonar-lsregistrationdaemon restart
```

## Using the *shared* Submodule
This repository contains a [git submodule](http://git-scm.com/book/en/v2/Git-Tools-Submodules) to the perfSONAR [shared](https://github.com/perfsonar/perl-shared) repository. This submodule is used to access common perfSONAR libraries. You will find a number of symbolic links to these modules under *lib*. The use of a submodule has a few implications when working with the code in this repository:

* As previously noted, when you clone the repository for the first time, you will want to use the `--recursive` option to make sure the submodule tree is included. If you do not, any symbolic links under *lib* will be broken in your local copy. If you forget the `--recursive` option, you can pull the submodule tree with the following commands:

    ```bash
    git submodule init
    git submodule update
    ```
* When you are editing files under *lib* be sure to check if you are working on an actual file or whether it's a link to something under *shared*. In general it is better to make changes to the *shared* submodule by editing the *shared* repository directly. If however you do make changes while working in this repository, see the [git submodule page](http://git-scm.com/book/en/v2/Git-Tools-Submodules#Working-on-a-Project-with-Submodules) for more details on pushing those changes to the server.
* Keep in mind that a submodule points at a specific revision of the repository it is referencing. As such if a new commit is made to the shared submodule's repository, this project will not get the change automatically. Instead it will still point at the old revision. To update to the latest revision of the *shared* submodule repository run the following commands:

    ```bash
    git submodule foreach git pull origin master
    git commit -a -m "Updating to latest shared"
    git push
    ```
* If you want to include a new file from the *shared* submodule, create a symbolic link under *lib*. For example, if you were to add a reference to the  *perfSONAR_PS::Utils::DNS* module you would run the following:

    ```bash
    mkdir -p lib/perfSONAR_PS/Utils/
    cd lib/perfSONAR_PS/Utils/
    ln -s ../../../shared/lib/perfSONAR_PS/Utils/DNS.pm DNS.pm
    ```
For more information on using the submodule, see the *shared/README.md* file or access it [here](https://github.com/perfsonar/perl-shared/blob/master/README.md) 

## Running in Vagrant

This repository allows you to use [Vagrant](https://www.vagrantup.com) to create a VM on [VirtualBox](https://www.virtualbox.org) with the necessary components installed. The default VM is based on CentOS 7 and creates a shared folder in the VM that points at the top-level of your checked-out copy. This allows you to edit files on your base system and have the changes automatically appear in the VM.

### Installation
1. Install [VirtualBox](https://www.virtualbox.org) according the the instructions on their site for your system. 
1. Install [Vagrant](https://www.vagrantup.com) according the the instructions on their site for your system. 
1. Install the vagrant-vbguest and vagrant-reload plugins with the following commands:
    ```bash
    vagrant plugin install vagrant-vbguest
    vagrant plugin install vagrant-reload
    ```
### Starting the VM
1. Clone this github repo
1. Start the VM with `vagrant up`. The first time you do this it will take awhile to create the initial VM.

### Using the VM
* The VM sets-up a lookup service wuth port forwarding by default so you can access a test lookup service from the host system. By default, your ls-registration-daemon will register to this local lookup-service. You can access the lookup service by visiting http://127.0.0.1:8090/lookup/records on the host system.
* Any changes you make to the checked-out code on your host system get reflected in the host VM under the `/vagrant` directory
* The following symlinks are setup to files in the git copy of the code:
    
    * /etc/perfsonar -> /vagrant/vagrant-data/pslsreg-el7/etc/perfsonar
* You can clear out the contents of the lookup service by running the `mongo lookup` followed by `db.services.remove({})`
* Run ``vagrant reload`` to restart the VM
* Run ``vagrant suspend`` to freeze the VM. Running ``vagrant up`` again will restore the state it was in when you suspended it.
* Run ``vagrant halt`` to shutdown the VM. Running ``vagrant up`` again will run through the normal boot process.
* Run ``vagrant destory`` to completely delete the VM. Running again ``vagrant up`` will build a brand new VM.



