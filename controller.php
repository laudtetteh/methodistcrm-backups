<?php

/**
* str_cln()
* A little trick to temporarily replace spaces in strings
* with '%%' to send to backup shell script
* @param string $string
* @return string
*/
public function str_cln($string) {
    // Clean up spaces in strings
    return str_replace(' ', '%%', $string);
}

/**
* Run backup
* backup()
* @param Request $request
* @return response
*/
public function backup(Request $request) {
    // Get app environment - Production/Staging/Local
    $app_env = config('app.env');
    $app_env_sh = escapeshellarg($app_env);
    // Get app base path
    $base_path = base_path();

    $resultHtml = [
        [
            'scripts' => [],
            'boxes' => [
                [
                    'title' => 'Success',
                    'box' => '_box-default',
                    'temp' => 'tools/_success',
                    'scheme' => 'info',
                    'data' => [],
                ],
            ],
        ],
    ];

    // Check if user added a description, then proceed
    if ($request->has('description')) {
        // Clean up the description
        $description_sh = escapeshellarg($this->str_cln($request->description));
        // Prepend the archive name with current environment - Prod/Staging/Local
        $prefix = $app_env.'_';
        $date_time_db = escapeshellarg($this->str_cln(\Carbon\Carbon::now()->format('Y/m/d H:i:s')));
        // Date for MySQL `created_at` field
        $date_cr_mod_db = escapeshellarg($this->str_cln(\Carbon\Carbon::now()->format('Y-m-d H:i:s')));
        $date_time_sh = \Carbon\Carbon::now()->format('Y-m-d-H-i-s');
        $timestamp = \Carbon\carbon::now()->timestamp;
        // Use timestamp as Backup id
        $backup_id_sh = escapeshellarg($timestamp);
        // Replace dashes with underscores in archive name
        $cleanName = str_replace('-', '_', "$prefix$date_time_sh");

        $archive_name_db = "$cleanName.zip";
        // Make sure archive name is acceptable by Linux
        $archive_name_sh = escapeshellarg($archive_name_db);
        // Make sure script path is acceptable by Linux
        $script_path = escapeshellarg($base_path . '/.backup_user.sh');
        // Make sure User Id is acceptable by Linux
        $creator_user_id_sh = escapeshellarg(\Auth::id());
        // Execute the .backup_user.sh script
        $output = exec("$script_path $app_env_sh $date_time_db $archive_name_sh $description_sh $creator_user_id_sh $backup_id_sh $date_cr_mod_db");

    } else {
        // If user forgot to input a description, display error
        return response()->json(['error' => 'Your description text is invalid.']);
    }

    // If the script execution is successfull
    if( strpos($output, 'BACKUP COMPLETE') !== false ) {
        // Return a success message
        return response()->json(['success', 'Backup created!']);

    } else {
        // Return an error message
        return response()->json(['error', 'Backup failed!']);
    }

    return response('');
}
