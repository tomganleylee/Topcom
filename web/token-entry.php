<?php
session_start();
$message = '';
$messageType = '';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['submit'])) {
    if ($_POST['submit'] === 'oauth2_token') {
        $token_json = trim($_POST['oauth2_token']);

        // Validate JSON format
        $token_data = json_decode($token_json, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            $message = 'Invalid token format. Please paste the complete JSON token including curly braces.';
            $messageType = 'error';
        } elseif (!isset($token_data['access_token'])) {
            $message = 'Token missing access_token. Make sure you copied the entire token.';
            $messageType = 'error';
        } else {
            // Check for refresh token
            $has_refresh = isset($token_data['refresh_token']);

            // Create rclone configuration with OAuth2 token
            $config = "[dropbox]\n";
            $config .= "type = dropbox\n";
            $config .= "token = $token_json\n";

            // Save configuration
            $temp_config = '/tmp/rclone_oauth2.conf';
            file_put_contents($temp_config, $config);

            // Create directory and install config
            exec('sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone 2>&1', $output, $return_code);
            exec('sudo cp ' . escapeshellarg($temp_config) . ' /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);
            exec('sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);
            exec('sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);

            // Test connection
            exec('sudo -u camerabridge rclone lsd dropbox: 2>&1', $output, $return_code);

            if ($return_code == 0) {
                if ($has_refresh) {
                    $message = 'Success! Dropbox configured with OAuth2 and automatic token refresh. Your token will never expire!';
                } else {
                    $message = 'Success! Dropbox configured. Warning: No refresh token detected - token may expire.';
                }
                $messageType = 'success';

                // Restart service if running
                exec('sudo systemctl restart camera-bridge 2>/dev/null');
            } else {
                $message = 'Failed to connect to Dropbox. Please check your token and try again.';
                $messageType = 'error';
            }

            // Clean up temp file
            unlink($temp_config);
        }
    } elseif ($_POST['submit'] === 'legacy_token') {
        // Legacy token support (backward compatibility)
        $token = trim($_POST['dropbox_token']);

        if (!empty($token)) {
            // Create old-style config
            $config = "[dropbox]\n";
            $config .= "type = dropbox\n";
            $config .= "token = {\"access_token\":\"$token\",\"token_type\":\"bearer\",\"expiry\":\"0001-01-01T00:00:00Z\"}\n";

            $temp_config = '/tmp/rclone_legacy.conf';
            file_put_contents($temp_config, $config);

            exec('sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone 2>&1', $output, $return_code);
            exec('sudo cp ' . escapeshellarg($temp_config) . ' /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);
            exec('sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);
            exec('sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);

            exec('sudo -u camerabridge rclone lsd dropbox: 2>&1', $output, $return_code);

            if ($return_code == 0) {
                $message = 'Dropbox configured with legacy token. Note: This token may expire - consider using OAuth2 method.';
                $messageType = 'warning';
                exec('sudo systemctl restart camera-bridge 2>/dev/null');
            } else {
                $message = 'Failed to connect to Dropbox. Token may be invalid or expired.';
                $messageType = 'error';
            }

            unlink($temp_config);
        }
    }
}

// Check current configuration status
$config_status = 'Not Configured';
$token_type = '';
if (file_exists('/home/camerabridge/.config/rclone/rclone.conf')) {
    $config_content = @file_get_contents('/home/camerabridge/.config/rclone/rclone.conf');
    if (strpos($config_content, '[dropbox]') !== false) {
        $config_status = 'Configured';
        if (strpos($config_content, 'refresh_token') !== false) {
            $token_type = 'OAuth2 with auto-refresh';
        } else {
            $token_type = 'Legacy token (may expire)';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Camera Bridge - Dropbox Token Entry</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 800px;
            width: 100%;
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        .status-bar {
            background: rgba(255,255,255,0.1);
            padding: 10px;
            border-radius: 10px;
            margin-top: 15px;
        }
        .content {
            padding: 30px;
        }
        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 30px;
            border-bottom: 2px solid #e0e0e0;
        }
        .tab {
            padding: 12px 24px;
            background: none;
            border: none;
            color: #666;
            font-size: 1em;
            cursor: pointer;
            position: relative;
            transition: color 0.3s;
        }
        .tab.active {
            color: #667eea;
        }
        .tab.active::after {
            content: '';
            position: absolute;
            bottom: -2px;
            left: 0;
            right: 0;
            height: 2px;
            background: #667eea;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        .method-card {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 25px;
        }
        .method-title {
            font-size: 1.3em;
            color: #333;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .badge {
            background: #4caf50;
            color: white;
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 0.8em;
        }
        .badge.warning {
            background: #ff9800;
        }
        .instructions {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .instructions h3 {
            color: #1976d2;
            margin-bottom: 15px;
        }
        .instructions ol {
            margin-left: 20px;
            line-height: 1.8;
        }
        .instructions code {
            background: #263238;
            color: #aed581;
            padding: 2px 8px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
        }
        .form-group {
            margin-bottom: 25px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #333;
        }
        textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-family: monospace;
            font-size: 0.95em;
            min-height: 150px;
            resize: vertical;
        }
        textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        input[type="text"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 1em;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 14px 30px;
            border-radius: 10px;
            font-size: 1.1em;
            font-weight: 500;
            cursor: pointer;
            transition: transform 0.3s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .message {
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .message.success {
            background: #d4edda;
            color: #155724;
            border-left: 4px solid #28a745;
        }
        .message.error {
            background: #f8d7da;
            color: #721c24;
            border-left: 4px solid #dc3545;
        }
        .message.warning {
            background: #fff3cd;
            color: #856404;
            border-left: 4px solid #ffc107;
        }
        .token-example {
            background: #263238;
            color: #aed581;
            padding: 15px;
            border-radius: 8px;
            font-family: monospace;
            font-size: 0.85em;
            overflow-x: auto;
            margin: 15px 0;
        }
        .help-text {
            color: #666;
            font-size: 0.9em;
            margin-top: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📷 Camera Bridge</h1>
            <p>Dropbox Configuration</p>
            <div class="status-bar">
                Status: <?php echo $config_status; ?>
                <?php if ($token_type): ?>
                    (<?php echo $token_type; ?>)
                <?php endif; ?>
            </div>
        </div>

        <div class="content">
            <?php if ($message): ?>
                <div class="message <?php echo $messageType; ?>">
                    <?php echo htmlspecialchars($message); ?>
                </div>
            <?php endif; ?>

            <div class="tabs">
                <button class="tab active" onclick="switchTab('oauth2')">OAuth2 Token (Recommended)</button>
                <button class="tab" onclick="switchTab('legacy')">Legacy Token</button>
            </div>

            <!-- OAuth2 Tab -->
            <div id="oauth2" class="tab-content active">
                <div class="method-card">
                    <div class="method-title">
                        OAuth2 with Refresh Token
                        <span class="badge">Auto-Renewal</span>
                    </div>

                    <div class="instructions">
                        <h3>How to Get OAuth2 Token:</h3>
                        <ol>
                            <li>On a computer with a web browser, open terminal/command prompt</li>
                            <li>Run command: <code>rclone authorize dropbox</code></li>
                            <li>Your browser will open - log in to Dropbox</li>
                            <li>Click "Allow" to authorize</li>
                            <li>Copy the ENTIRE token output (including curly braces)</li>
                        </ol>
                    </div>

                    <div class="token-example">
                        Example token format:<br>
                        {"access_token":"sl.xxx...","token_type":"bearer","refresh_token":"xxx...","expiry":"2025-01-01T00:00:00.000000-00:00"}
                    </div>

                    <form method="POST">
                        <div class="form-group">
                            <label for="oauth2_token">Paste Complete OAuth2 Token:</label>
                            <textarea
                                name="oauth2_token"
                                id="oauth2_token"
                                placeholder='Paste the entire JSON token here, including the curly braces { }'
                                required></textarea>
                            <div class="help-text">
                                ✓ Includes refresh token for automatic renewal<br>
                                ✓ Never expires once configured<br>
                                ✓ Works with Dropbox Business
                            </div>
                        </div>
                        <button type="submit" name="submit" value="oauth2_token">Configure with OAuth2 Token</button>
                    </form>
                </div>
            </div>

            <!-- Legacy Tab -->
            <div id="legacy" class="tab-content">
                <div class="method-card">
                    <div class="method-title">
                        Legacy Access Token
                        <span class="badge warning">May Expire</span>
                    </div>

                    <div class="instructions">
                        <h3>How to Get Legacy Token:</h3>
                        <ol>
                            <li>Visit <a href="https://www.dropbox.com/developers/apps" target="_blank">Dropbox App Console</a></li>
                            <li>Create a new app or select existing</li>
                            <li>Go to Settings tab</li>
                            <li>Generate access token</li>
                            <li>Copy the token (starts with sl.)</li>
                        </ol>
                    </div>

                    <form method="POST">
                        <div class="form-group">
                            <label for="dropbox_token">Dropbox Access Token:</label>
                            <input
                                type="text"
                                name="dropbox_token"
                                id="dropbox_token"
                                placeholder="sl.xxxxx..."
                                required>
                            <div class="help-text">
                                ⚠ This token may expire and need manual renewal<br>
                                ⚠ Consider using OAuth2 method for better reliability
                            </div>
                        </div>
                        <button type="submit" name="submit" value="legacy_token">Configure with Legacy Token</button>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script>
        function switchTab(tabName) {
            // Hide all tabs
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            document.querySelectorAll('.tab').forEach(tab => {
                tab.classList.remove('active');
            });

            // Show selected tab
            document.getElementById(tabName).classList.add('active');
            event.target.classList.add('active');
        }
    </script>
</body>
</html>