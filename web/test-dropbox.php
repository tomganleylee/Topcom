<?php
header('Content-Type: text/plain');

echo "Testing Dropbox Configuration Setup\n";
echo "===================================\n\n";

// Test 1: Create directory
echo "1. Creating directory structure...\n";
exec('sudo mkdir -p /home/camerabridge/.config/rclone 2>&1', $output, $return);
echo "   Result: " . ($return == 0 ? "SUCCESS" : "FAILED") . "\n";
if ($return != 0) {
    echo "   Output: " . implode("\n   ", $output) . "\n";
}

// Test 2: Create test config
echo "\n2. Creating test configuration...\n";
$test_config = "[dropbox]\ntype = dropbox\ntoken = {\"access_token\":\"test\",\"token_type\":\"bearer\"}\n";
$temp_file = '/tmp/test_rclone_' . time() . '.conf';
file_put_contents($temp_file, $test_config);
exec('sudo cp ' . escapeshellarg($temp_file) . ' /home/camerabridge/.config/rclone/test.conf 2>&1', $output, $return);
echo "   Result: " . ($return == 0 ? "SUCCESS" : "FAILED") . "\n";

// Test 3: Set permissions
echo "\n3. Setting permissions...\n";
exec('sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/test.conf 2>&1', $output, $return);
echo "   Result: " . ($return == 0 ? "SUCCESS" : "FAILED") . "\n";

// Test 4: Test rclone command
echo "\n4. Testing rclone command...\n";
exec('sudo -u camerabridge rclone version 2>&1', $output, $return);
echo "   Result: " . ($return == 0 ? "SUCCESS" : "FAILED") . "\n";
echo "   Output: " . implode("\n   ", $output) . "\n";

// Clean up
unlink($temp_file);
@unlink('/home/camerabridge/.config/rclone/test.conf');

echo "\n===================================\n";
echo "If all tests show SUCCESS, the permissions are correctly configured.\n";
?>
