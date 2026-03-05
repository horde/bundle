<?php
/**
 * Router script for PHP built-in development server.
 *
 * Usage (from bundle directory):
 *   php -S localhost:8000 -t ../web scripts/router.php
 *
 * Usage (from horde-dev-server.sh):
 *   php -S localhost:8585 -t /path/to/web /path/to/scripts/router.php
 *
 * This script mimics Apache's mod_rewrite behavior:
 * - If the requested file exists, serve it directly
 * - Otherwise, route through rampage.php front controller
 *
 * Copyright 2026 Horde LLC (http://www.horde.org/)
 */

// Get the requested URI
$uri = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));

// Remove query string for file checks
$path = strtok($uri, '?');

// Build absolute file path (from document root)
$file = $_SERVER['DOCUMENT_ROOT'] . $path;

// If requesting the router itself, deny
if ($path === '/router.php' || basename($path) === 'router.php') {
    http_response_code(403);
    echo "403 Forbidden\n";
    return false;
}

// If the request is for a real file or directory, serve it
if (file_exists($file)) {
    // If it's a directory, try index.php
    if (is_dir($file)) {
        $indexFile = rtrim($file, '/') . '/index.php';
        if (file_exists($indexFile)) {
            require $indexFile;
            return true;
        }
        // Let PHP serve directory listing
        return false;
    }

    // For PHP files, execute them
    if (pathinfo($file, PATHINFO_EXTENSION) === 'php') {
        require $file;
        return true;
    }

    // For other files (CSS, JS, images), let PHP serve them
    return false;
}

// No file exists - route through rampage.php front controller
// This is equivalent to Apache's: RewriteRule ^(.*)$ rampage.php [QSA,L]
$rampagePath = $_SERVER['DOCUMENT_ROOT'] . '/rampage.php';
if (!file_exists($rampagePath)) {
    http_response_code(500);
    echo "500 Internal Server Error: rampage.php not found\n";
    echo "Expected at: $rampagePath\n";
    return false;
}

$_SERVER['SCRIPT_NAME'] = '/rampage.php';
$_SERVER['SCRIPT_FILENAME'] = $rampagePath;
require $rampagePath;
return true;
