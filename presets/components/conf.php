<?php
/**
 * Horde Components Configuration File
 *
 * This file contains the configuration settings for the Horde components
 * helper.
 *
 * Strings should be enclosed in 'quotes'.
 * Integers should be given literally (without quotes).
 * Boolean values may be true or false (never quotes).
 */

/* PEAR server name. Only change for testing purposes. */
$conf['releaseserver'] = 'pear.horde.org';

/* PEAR server directory. Only change for testing purposes. */
$conf['releasedir'] = '/horde/web/pear.horde.org';

/* Username for horde.org.
 * Make sure you belong to the "horde" group there. */
$conf['horde_user'] = '';

/* Needed to update the Whups versions */
$conf['horde_pass'] = '';

/* From: address for announcements. */
$conf['from'] = 'Full name <user@horde.org>';

/* Path to a checkout of the horde-web repository. */
$conf['web_dir'] = '/var/www/horde-web';

/* Org: The Github organisation to release for */
//$conf['org'] = 'horde';

/* composer_repo - Type of loader hints to generate */
// $conf['composer_repo'] = 'vcs'; // generate a vcs repo source per horde internal dependency
$conf['composer_repo'] = 'satis:https://horde-satis.maintaina.com'; // generate a satis source for all horde namespace

/* composer_version - tweak all dependency version to a common branch name or version */
// It is more likely you would want this on the commandline for special cases
$conf['composer_version'] = 'dev-master'; // depend on master branch
// $conf['composer_version'] = 'dev-staging'; // depend on a staging branch - components won't check if it even exists!



/* Well known composer native substitutes for pear dependencies */
$conf['composer_opts']['pear-substitutes']['pear.php.net/Archive_Tar'] = array('source' => 'Packagist', 'name' => 'pear/archive_tar');
$conf['composer_opts']['pear-substitutes']['pear.php.net/PHP_CodeSniffer'] = array('source' => 'Packagist', 'name' => 'squizlabs/php_codesniffer');
$conf['composer_opts']['pear-substitutes']['pear.phpunit.de/phpcpd'] = array('source' => 'Packagist', 'name' => 'sebastian/phpcpd');
$conf['composer_opts']['pear-substitutes']['pear.phpunit.de/phpdcd'] = array('source' => 'Packagist', 'name' => 'sebastian/phpdcd');
$conf['composer_opts']['pear-substitutes']['pear.phpunit.de/phploc'] = array('source' => 'Packagist', 'name' => 'phploc/phploc');
