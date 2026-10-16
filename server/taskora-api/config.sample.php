<?php
// Copy this file to config.php and fill it in. See SETUP-GUIDE.md, Part 2.
return [
    // cPanel > MySQL Databases
    'db_host' => 'localhost',
    'db_name' => 'cpaneluser_taskora',
    'db_user' => 'cpaneluser_taskora',
    'db_pass' => 'PUT-THE-DATABASE-PASSWORD-HERE',

    // Firebase console > Project settings > General > Project ID
    'firebase_project_id' => 'taskora-4f3f0',

    // Safety limits
    'max_changes_per_request' => 500,
    'max_doc_bytes' => 1000000, // 1 MB per item
    'page_size' => 1000,
];
