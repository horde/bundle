### pre-made configs

You can provide pre-made configuration for your apps to be pulled into your
deployment upon install/update.

Create a presets/app dir and put files there like prefs.local.php
or a ready to run conf.php for your scenario.

Existing configs will not be overwritten.

Example: Deploy with a premade backends file for passwd app:

```
presets/passwd/backends.local.php
```

