<?php
if (file_exists(__DIR__ . '/horde/config/conf.php')) {
    require_once __DIR__ . '/horde/index.php';
} elseif (file_exists(__DIR__ . '/wizard/index.php')) {
    require_once __DIR__ . '/wizard/index.php';
} else {
    printf("Please create a %s file and then run 'composer horde-reconfigure' to activate Horde", dirname(__DIR__) . '/var/config/horde/conf.php');
}
