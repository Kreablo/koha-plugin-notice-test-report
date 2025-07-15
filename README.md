# Notice Test Report
Render some notice messages.

## Preparing installation

* Koha-plugins must be activated in koha-conf.xml and the plugin directory must exist and be writable to the koha process.

# Installation

Upload the plugin koha administration -> manage plugins

# Run
From koha administration -> manage plugins -> NoticeTestReport -> actions -> run report

# Building the plugin

```sh
> perl Makefile.PL
> make
> make kpzdist
```
