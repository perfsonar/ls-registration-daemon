[![Build Status (Debian)](https://perfsonar-dev3.grnoc.iu.edu/jenkins/buildStatus/icon?job=ls-registration-daemon-debian-source)](https://perfsonar-dev3.grnoc.iu.edu/jenkins/view/Debian/job/ls-registration-daemon-debian-source/)

# perfSONAR Lookup Service Registration Daemon

The Lookup Service (LS) Registration daemon registers and maintains records with the lookup service. It includes features such as autodetecting hardware details of the host on which it is running and registering these as host and interface records in the Lookup Seervice. It also registers service records of the various perfSONAR components, in many cases detecting whether the service is up prior to registering and autodetcting service specific features where applicable. It opaquely handles most record management tasks, such as refreshing a record and avoiding duplicate registrations. It is designed to be extensible so that new registration types may be added with minimal effort.

##Getting the Code
You may checkout the code with the following command:

```
git clone --recursive https://github.com/perfsonar/ls-registration-daemon.git
```

Note the use of the `--recursive` option to ensure any submodule trees are included in the clone.

##Building and Installing

To install the code on your system run:

```bash
make install
```

##Packaging
You may create a source tarball of this code with the following:

```bash
make dist
```
##Running 

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

##Using the *shared* Submodule
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


