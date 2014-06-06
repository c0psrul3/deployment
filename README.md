Web Application Deployment
====================================



Files worth mentioning
======================

## Main Interface ##
------------------------------------------------------------------------------
 * ./deployment.cli is a commandline interactive script that will read
   deployment configurations found in config/<reponame>.inc
 * `export DEPLOYUSERNAME="<username>"` can be used to provide the deployment
   system with your username.  If one is not provided, this value will be asked
   for during launch of the cli.

## Requirements ##
------------------------------------------------------------------------------
 * shyaml  - this is a required program for (bash) commandline yaml parsing
      see : https://github.com/0k/shyaml


## Example Configuration File ##
------------------------------------------------------------------------------
 * ./config/test.yaml
 * Configuration example is in [YAML](http://www.yaml.org) format.  


#### this file is incomplete ####

Author
======

Mike Nichols -- mike@myownsoho.net , mnichols@benchmarkeducation.com

[Benchmark Education Company](http://www.benchmarkeducation.com)
