# fluent-plugin-syscheck

[Fluentd](https://fluentd.org/) input plugins to check system parts.



## Installation

### RubyGems

```
$ gem install fluent-plugin-syscheck
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-syscheck"
```

And then execute:

```
$ bundle
```



## plugin : syscheck_mounts

### configuration

Parameters are:

| parameter         | type   | purpose                                  |
|-------------------|--------|------------------------------------------|
| tag               | string | tag to emit event on                     |
| interval          | time   | interval to exec mount check             |
| timeout           | time   | timeout for a mountpoint check           |
| enabled_fs_types  | array  | list of fstype to enable only            |
| disabled_fs_types | array  | list of fstype to disable explicitly     |
| error_only        | bool   | generate event on mount check error only |

### examples

``` text
<source>
  @type syscheck_mounts

  tag test
  interval 10
  enabled_fs_types zfs, xfs
  error_only false
</source>
```

## Copyright

* Copyright(c) 2025- Thomas Tych
* License
  * Apache License, Version 2.0
